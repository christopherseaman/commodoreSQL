#!/bin/bash
set -euo pipefail

# Resolve paths independently of the caller's working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

# Load environment configuration.
set -o allexport
source "$SCRIPT_DIR/dot.env"
set +o allexport
DUCKDB="${DUCKDB:-duckdb}"

PARQUET_TMP_DIR="$REPO_ROOT/tmp/parquet_exports"
PARQUET_OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/output}"
CONFIG="$(envsubst < sql/config.sql)"
mkdir -p "$PARQUET_TMP_DIR" "$PARQUET_OUTPUT_DIR"

echo "Export process started at: $(date)"

# Discover and process SQL export files
mapfile -t export_files < <(find sql/exports -maxdepth 1 -type f -name "*.sql" | sort)
total_exports=${#export_files[@]}
current_export=0
successful_exports=0
failed_exports=0

echo "Found ${total_exports} export files to process"

for export_file in "${export_files[@]}"; do
    filename=$(basename "$export_file" .sql)
    export_name="${filename#*_}"
    output_file="${PARQUET_OUTPUT_DIR}/${export_name}.parquet"
    output_file_sql=${output_file//\'/\'\'}
    
    current_export=$((current_export + 1))
    echo "===== Exporting ${export_name} (${current_export}/${total_exports}) ====="
    
    # Prepare export file with environment variables
    processed_sql="$PARQUET_TMP_DIR/${filename}.sql"
    export_sql="$PARQUET_TMP_DIR/${filename}_export.sql"
    envsubst < "$export_file" > "$processed_sql"
    # Export wrappers are bare SELECTs terminated by semicolons. Remove only the
    # final terminator before nesting the query inside COPY (...).
    sed -i '$ s/;[[:space:]]*$//' "$processed_sql"
    
    # Extract partition columns if specified
    partition_by=$(awk '/^-- @PARTITION_BY:/ {sub(/^-- @PARTITION_BY: */, ""); print; exit}' "$processed_sql")
    
    # Generate Parquet export SQL with optimized settings
    if [ -n "$partition_by" ]; then
        cat > "$export_sql" << EOF
${CONFIG}

-- Export data to compressed Parquet format
COPY ($(cat "$processed_sql")) TO '${output_file_sql}' (
    FORMAT PARQUET,
    ROW_GROUP_SIZE 100000,
    COMPRESSION 'ZSTD',
    PARTITION_BY (${partition_by})
);
EOF
    else
        cat > "$export_sql" << EOF
${CONFIG}

-- Export data to compressed Parquet format
COPY ($(cat "$processed_sql")) TO '${output_file_sql}' (
    FORMAT PARQUET,
    ROW_GROUP_SIZE 100000,
    COMPRESSION 'ZSTD'
);
EOF
    fi

    # Execute export and track results
    if ${DUCKDB} -bail -readonly "${MAIN_DB}" < "$export_sql"; then
        echo "✓ Successfully exported ${export_name} to parquet"
        successful_exports=$((successful_exports + 1))
    else
        echo "✗ Failed to export ${export_name}"
        failed_exports=$((failed_exports + 1))
        exit 1
    fi
    
    echo ""
done

# Report export process summary
echo "===== Export Summary ====="
echo "Total exports: ${total_exports}"
echo "Successful: ${successful_exports}"
echo "Failed: ${failed_exports}"

if [ "$failed_exports" -ne 0 ]; then
    exit 1
fi
