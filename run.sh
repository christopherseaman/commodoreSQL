#!/bin/bash

# Fail fast on setup errors
set -e

# Load environment configuration
set -o allexport
source dot.env
set +o allexport

# Define default SQL processing sequence
if [ -z "${SQL_FILES+x}" ]; then
    SQL_FILES=(
        "0_setup.sql"
        "1_mailing_lists.sql"
        "2_merged_records.sql"
    )
fi

# Prepare output directories
mkdir -p tmp output

# Set default DuckDB executable
DUCKDB=${DUCKDB:-"duckdb"}

echo "Pipeline started at: $(date)"

# Configure DuckDB runtime settings
export CONFIG="
SET memory_limit='${MEM_LIMIT}';
SET temp_directory='./tmp';
SET threads=${NUM_THREADS};
"

# Execute SQL files in sequence
for sql_file in "${SQL_FILES[@]}"; do
    echo "Processing ${sql_file}..."
    envsubst < "sql/${sql_file}" > "tmp/${sql_file}"
    
    # Execute with error handling
    time ${DUCKDB} "${MAIN_DB}" < "tmp/${sql_file}"
    
    # Verify views after setup
    if [ "$sql_file" = "0_setup.sql" ]; then
        echo "Verifying views..."
        ${DUCKDB} "${MAIN_DB}" -c "SELECT name FROM sqlite_master WHERE type='view';"
    fi
done

# Remove temporary files
echo "Cleaning temporary files..."
rm -f tmp/*.sql

# Run export process
echo "Generating exports..."
./export_all.sh

echo "Pipeline completed at: $(date)"
