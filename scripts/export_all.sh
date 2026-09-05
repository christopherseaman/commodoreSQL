#!/bin/bash
set -euo pipefail

# Detect repo root and script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to script directory for relative paths to work
cd "$SCRIPT_DIR"

# Load environment variables
set -o allexport
source dot.env
set +o allexport
DUCKDB="${DUCKDB:-duckdb}"

# Override directories to use repo root
TMP_EXPORTS_DIR="${REPO_ROOT}/tmp/exports"
OUTPUT_EXPORTS_DIR="${REPO_ROOT}/output/exports"

# Create required directories
mkdir -p "${TMP_EXPORTS_DIR}" "${OUTPUT_EXPORTS_DIR}"

# Set CONFIG if not already set
if [ -z "${CONFIG+x}" ]; then
    echo "Loading DuckDB configuration from sql/config.sql..."
    export CONFIG=$(envsubst < sql/config.sql)
fi

# Count total exports
total_exports=$(find sql/exports -name "*.sql" | wc -l)
current_export=0

# Function to process a single export
process_export() {
    local input_file=$1
    local output_file=$2
    local export_name=$(basename "$input_file" .sql)
    
    # Increment counter
    current_export=$((current_export + 1))
    
    echo "===== Processing $export_name ($current_export/$total_exports) ====="

    # Create temporary SQL file with configuration
    cat > "${TMP_EXPORTS_DIR}/$export_name.sql" << EOF
-- Load DuckDB configuration
${CONFIG}

-- Create temporary table from the export query
CREATE OR REPLACE TEMP TABLE export_table AS
$(cat "$input_file");

-- Export to CSV using native COPY command
COPY export_table TO '$output_file' (
    HEADER,
    DELIMITER ','
);

-- Clean up
DROP TABLE IF EXISTS export_table;
EOF
    
    # Process the export
    nice -n 19 $DUCKDB -bail -readonly "${MAIN_DB}" < "${TMP_EXPORTS_DIR}/$export_name.sql"
}

# Process each export file
for export_file in sql/exports/*.sql; do
    if [ -f "$export_file" ]; then
        export_name=$(basename "$export_file" .sql)
        output_file="${OUTPUT_EXPORTS_DIR}/${export_name}.csv"
        process_export "$export_file" "$output_file"
    fi
done

echo "All exports completed!"
