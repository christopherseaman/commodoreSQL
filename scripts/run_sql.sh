#!/bin/bash

# Fail fast on setup errors
set -e

# Detect repo root and script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to script directory for relative paths to work
cd "$SCRIPT_DIR"

# Load environment configuration
set -o allexport
source dot.env
set +o allexport

# Override output directories to use repo root
export OUTPUT_DIR="${REPO_ROOT}/output"
TMP_DIR="${REPO_ROOT}/tmp"

# Configure DuckDB runtime settings
export CONFIG=$(envsubst < sql/config.sql)

# Define SQL processing stages
IMPORT_SQL=(
    "0_setup.sql"
    "0b_state_region.sql"
    "1_bookprices_import.sql"
    "1a_supply_classification.sql"
    "1b_section_filter.sql"
    "2_oer_classification.sql"
    "2b_pricing_oer_ia.sql"
    "2c_pricing_wide.sql"
    "2d_data_quality.sql"
)

EDA_SQL=(
    "3_mailing_lists.sql"
    "4_merged_records.sql"
)

# Populate EXPORT_SQL from exports directory
EXPORT_SQL=()
if [ -d "sql/exports" ]; then
    while IFS= read -r export_file; do
        EXPORT_SQL+=("exports/$(basename "$export_file")")
    done < <(find sql/exports -maxdepth 1 -name "*.sql" -type f | sort)
fi

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
    time nice -n 19 ${DUCKDB} "${MAIN_DB}" < "${TMP_DIR}/${export_name}.sql"
}

# Process and run SQL files
for sql_file in "${SQL_FILES[@]}"; do
    # Determine stage for logging
    stage="UNKNOWN"
    if [[ " ${IMPORT_SQL[@]} " =~ " ${sql_file} " ]]; then
        stage="IMPORT"
    elif [[ " ${EDA_SQL[@]} " =~ " ${sql_file} " ]]; then
        stage="EDA"
    elif [[ " ${EXPORT_SQL[@]} " =~ " ${sql_file} " ]]; then
        # Handle export files specially
        process_export "$sql_file"
        continue
    fi

    echo "[$stage] Processing ${sql_file}..."
    envsubst < "sql/${sql_file}" > "${TMP_DIR}/${sql_file}"

    # Execute with error handling
    time ${DUCKDB} "${MAIN_DB}" < "${TMP_DIR}/${sql_file}"

    # Debug: Check views after setup.sql
    if [ "$sql_file" = "0_setup.sql" ]; then
        echo "Checking tables after setup..."
        ${DUCKDB} "${MAIN_DB}" -c "SELECT name FROM sqlite_master WHERE type='table';"
    fi
done

# Verify critical tables exist before proceeding
echo "Verifying critical tables exist..."
${DUCKDB} "${MAIN_DB}" -c "
    SELECT name FROM sqlite_master 
    WHERE type='table' 
    AND name IN ('comprehensive_data', 'master_mailing', 'master_section', 'master_course');
"

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -f "${TMP_DIR}"/*.sql

echo "Pipeline completed at: $(date)"
