#!/bin/bash

# Fail fast on setup errors
set -e

# Detect repo root and script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to script directory for relative paths to work
cd "$SCRIPT_DIR"

# Load environment configuration
# Explicit process-environment values override dot.env. This lets memory-heavy
# stages be run with a safe one-off bound without editing the ignored local file.
RUN_SQL_MEM_LIMIT_OVERRIDE="${MEM_LIMIT-}"
RUN_SQL_NUM_THREADS_OVERRIDE="${NUM_THREADS-}"
set -o allexport
source dot.env
set +o allexport
if [ -n "$RUN_SQL_MEM_LIMIT_OVERRIDE" ]; then
    export MEM_LIMIT="$RUN_SQL_MEM_LIMIT_OVERRIDE"
fi
if [ -n "$RUN_SQL_NUM_THREADS_OVERRIDE" ]; then
    export NUM_THREADS="$RUN_SQL_NUM_THREADS_OVERRIDE"
fi
unset RUN_SQL_MEM_LIMIT_OVERRIDE RUN_SQL_NUM_THREADS_OVERRIDE

# Override output directories to use repo root
export OUTPUT_DIR="${REPO_ROOT}/output"
TMP_DIR="${REPO_ROOT}/tmp"

# Configure DuckDB runtime settings
export CONFIG=$(envsubst < sql/config.sql)

# Define SQL processing stages
IMPORT_SQL=(
    "0_cleanup.sql"
    "0_setup.sql"
    "0b_state_region.sql"
    "0c_recent_period.sql"
    "1_bookprices_import.sql"
    "1a_supply_classification.sql"
    "1b_section_enrollment.sql"
    "2_oer_classification.sql"
    "2b_course_material.sql"
    "2c_pricing_wide.sql"
    "2d_data_quality.sql"
)

EDA_SQL=(
    "3_mailing_lists.sql"
    "3b_master_material.sql"
    "4_merged_records.sql"
)

# Canonical analysis-model queries are bare SELECTs. Materialize them after EDA
# so exports and Metabase reuse the same definition without recomputing heavy
# rollups for every read.
MODEL_SQL=()
if [ -d "sql/models" ]; then
    while IFS= read -r model_file; do
        MODEL_SQL+=("models/$(basename "$model_file")")
    done < <(find sql/models -maxdepth 1 -name "*.sql" -type f | sort)
fi

# Populate EXPORT_SQL from exports directory
EXPORT_SQL=()
if [ -d "sql/exports" ]; then
    while IFS= read -r export_file; do
        EXPORT_SQL+=("exports/$(basename "$export_file")")
    done < <(find sql/exports -maxdepth 1 -name "*.sql" -type f | sort)
fi

# Mailing exports consume the persisted master selection refreshed by 3_mailing_lists.sql.
# Keep the explicit dependency list small and auditable so a same-invocation
# import cannot silently feed stale opt-out or catalog state to these wrappers.
MAILING_EXPORT_SQL=(
    "exports/10_master_mailing.sql"
    "exports/11_current_mailing.sql"
    "exports/11_recent_mailing.sql"
    "exports/20_california_mailing.sql"
    "exports/21_texas_mailing.sql"
    "exports/22_florida_mailing.sql"
    "exports/23_newyork_mailing.sql"
    "exports/24_texas_fall_series.sql"
    "exports/25_pennsylvania_mailing.sql"
    "exports/26_canada_mailing.sql"
    "exports/27_other_mailing.sql"
)

# Build SQL_FILES array based on stage flags
SQL_FILES=()

# Add IMPORT stage unless NO_IMPORT is set
if [ -z "${NO_IMPORT+x}" ]; then
    SQL_FILES+=("${IMPORT_SQL[@]}")
else
    echo "Skipping IMPORT stage (NO_IMPORT set)"
fi

# Add EDA stage unless NO_EDA is set
if [ -z "${NO_EDA+x}" ]; then
    SQL_FILES+=("${EDA_SQL[@]}")
    SQL_FILES+=("${MODEL_SQL[@]}")
else
    echo "Skipping EDA stage (NO_EDA set)"
fi

# Add EXPORT stage unless NO_EXPORT is set
if [ -z "${NO_EXPORT+x}" ]; then
    SQL_FILES+=("${EXPORT_SQL[@]}")
else
    echo "Skipping EXPORT stage (NO_EXPORT set)"
fi

# Allow custom SQL_FILES override if set
if [ ! -z "${CUSTOM_SQL_FILES+x}" ]; then
    SQL_FILES=("${CUSTOM_SQL_FILES[@]}")
    echo "Using custom SQL files: ${SQL_FILES[@]}"
fi

# Reject only the unsafe same-invocation dependency gap. Wrapper-only runs with
# NO_IMPORT reuse the last validated mailing selection; normal full runs include the
# mailing refresh before exports.
last_import_index=-1
last_mailing_refresh_index=-1
for sql_index in "${!SQL_FILES[@]}"; do
    sql_file="${SQL_FILES[$sql_index]}"
    if [[ " ${IMPORT_SQL[*]} " == *" ${sql_file} "* ]]; then
        last_import_index=$sql_index
    fi
    if [ "$sql_file" = "3_mailing_lists.sql" ]; then
        last_mailing_refresh_index=$sql_index
    fi
    if [[ " ${MAILING_EXPORT_SQL[*]} " == *" ${sql_file} "* ]] &&
       (( last_import_index >= 0 && last_mailing_refresh_index <= last_import_index )); then
        echo "Error: ${sql_file} follows IMPORT without a later 3_mailing_lists.sql refresh." >&2
        echo "Refresh mailing after the last selected IMPORT file and before each mailing export," >&2
        echo "or set NO_IMPORT=1 when exporting an already-refreshed database." >&2
        exit 1
    fi
done

# Exit early if no SQL files to process
if [ ${#SQL_FILES[@]} -eq 0 ]; then
    echo "No SQL files to process (all stages skipped)"
    exit 0
fi

# Validate SQL files exist
for sql_file in "${SQL_FILES[@]}"; do
    if [ ! -f "sql/${sql_file}" ]; then
        echo "Error: SQL file sql/${sql_file} not found"
        exit 1
    fi
done

# Prepare output directories
mkdir -p "${TMP_DIR}" "${OUTPUT_DIR}"

# Set default DuckDB executable
DUCKDB=${DUCKDB:-"duckdb"}

# Ensure export script is executable
chmod +x export_all.sh

# Verify pricing CSV exists (IMPORT stage only)
if [ -z "${NO_IMPORT+x}" ]; then
    if [ ! -f "${PRICING_CSV}" ]; then
        echo "Warning: Pricing CSV not found at ${PRICING_CSV}"
    fi
fi

echo "Pipeline started at: $(date)"
echo ""
echo "=== Pipeline Configuration ==="
echo "Database: ${MAIN_DB}"
echo "IMPORT stage: $([ -z "${NO_IMPORT+x}" ] && echo "ENABLED" || echo "SKIPPED")"
echo "EDA stage: $([ -z "${NO_EDA+x}" ] && echo "ENABLED" || echo "SKIPPED")"
echo "Analysis models: ${#MODEL_SQL[@]} discovered"
echo "EXPORT stage: $([ -z "${NO_EXPORT+x}" ] && echo "ENABLED" || echo "SKIPPED")"
echo "SQL files to process: ${#SQL_FILES[@]}"
if [ ${#SQL_FILES[@]} -gt 0 ]; then
    for sql_file in "${SQL_FILES[@]}"; do
        echo "  - ${sql_file}"
    done
fi
echo "=============================="
echo ""

# Set DuckDB configuration as an environment variable
#echo "Configuring DuckDB with memory_limit=${MEM_LIMIT} and threads=${NUM_THREADS}..."
export CONFIG=$(envsubst < sql/config.sql)

# Function to process export files (wraps query in temp table + COPY)
process_export() {
    local sql_file=$1
    local export_name=$(basename "$sql_file" .sql)
    local output_file="${OUTPUT_DIR}/${export_name}.csv"

    echo "[EXPORT] Processing ${sql_file}..."

    # Create temporary SQL with wrapping logic
    cat > "${TMP_DIR}/${export_name}.sql" << EOF
-- Load DuckDB configuration
${CONFIG}

-- Create temporary table from the export query
CREATE OR REPLACE TEMP TABLE export_table AS
$(envsubst < "sql/${sql_file}");

-- Export to CSV using native COPY command
COPY export_table TO '${output_file}' (
    HEADER,
    DELIMITER ','
);

-- Clean up
DROP TABLE IF EXISTS export_table;
EOF

    # Execute with lower priority
    time nice -n 19 ${DUCKDB} -bail "${MAIN_DB}" < "${TMP_DIR}/${export_name}.sql"
}

process_model() {
    local sql_file=$1
    local model_name
    model_name=$(basename "$sql_file" .sql)

    if [[ ! "$model_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
        echo "Error: invalid model filename: ${sql_file}"
        exit 1
    fi

    echo "[MODEL] Materializing ${model_name} from ${sql_file}..."
    {
        printf '%s\n' "${CONFIG}"
        if [ "$model_name" = "sample_material_10pct" ]; then
            printf 'DROP TABLE IF EXISTS sample10pct_materials;\n'
        fi
        printf 'CREATE OR REPLACE TABLE %s AS\n' "$model_name"
        envsubst < "sql/${sql_file}"
    } > "${TMP_DIR}/${model_name}.sql"

    time nice -n 19 ${DUCKDB} -bail "${MAIN_DB}" < "${TMP_DIR}/${model_name}.sql"
}

# Process and run SQL files
for sql_file in "${SQL_FILES[@]}"; do
    # Determine stage for logging
    stage="UNKNOWN"
    if [[ " ${IMPORT_SQL[@]} " =~ " ${sql_file} " ]]; then
        stage="IMPORT"
    elif [[ " ${EDA_SQL[@]} " =~ " ${sql_file} " ]]; then
        stage="EDA"
    elif [[ " ${MODEL_SQL[@]} " =~ " ${sql_file} " ]]; then
        process_model "$sql_file"
        continue
    elif [[ " ${EXPORT_SQL[@]} " =~ " ${sql_file} " ]]; then
        # Handle export files specially
        process_export "$sql_file"
        continue
    fi

    echo "[$stage] Processing ${sql_file}..."

    # Compatibility migration: #66 changed master_mailing from a VIEW to a TABLE.
    # DuckDB will not let DROP TABLE remove the old view, so remove that legacy
    # object once before the new idempotent table refresh executes.
    if [ "$sql_file" = "3_mailing_lists.sql" ]; then
        master_mailing_type=$(
            ${DUCKDB} -bail -csv -noheader "${MAIN_DB}" -c "
                SELECT table_type
                FROM information_schema.tables
                WHERE table_schema = 'main' AND table_name = 'master_mailing';
            "
        )
        if [ "$master_mailing_type" = "VIEW" ]; then
            echo "[MIGRATION] Dropping legacy master_mailing view..."
            ${DUCKDB} -bail "${MAIN_DB}" -c "DROP VIEW master_mailing;"
        fi
    fi

    envsubst < "sql/${sql_file}" > "${TMP_DIR}/${sql_file}"

    # Execute with error handling
    time ${DUCKDB} -bail "${MAIN_DB}" < "${TMP_DIR}/${sql_file}"

    # Debug: Check views after setup.sql
    if [ "$sql_file" = "0_setup.sql" ]; then
        echo "Checking tables after setup..."
        ${DUCKDB} -bail "${MAIN_DB}" -c "SELECT name FROM sqlite_master WHERE type='table';"
    fi
done

# Verify critical tables exist before proceeding
echo "Verifying critical tables exist..."
${DUCKDB} -bail "${MAIN_DB}" -c "
    SELECT name FROM sqlite_master 
    WHERE type='table' 
    AND name IN ('comprehensive_data', 'master_mailing', 'master_section', 'master_course');
"

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -f "${TMP_DIR}"/*.sql

echo "Pipeline completed at: $(date)"
