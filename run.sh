#!/bin/bash

# Exit on any error in the setup phase
set -e

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Define default SQL files if not set in dot.env
if [ -z "${SQL_FILES+x}" ]; then
    SQL_FILES=(
        "0_setup.sql"
        "1_mailing_lists.sql"
        "2_merged_records.sql"
    )
fi

# Create required directories
mkdir -p tmp output

# Set default for DUCKDB if not defined
DUCKDB=${DUCKDB:-"duckdb"}

echo "Pipeline started at: $(date)"

# Set DuckDB configuration as an environment variable
echo "Configuring DuckDB with memory_limit=${MEM_LIMIT} and threads=${NUM_THREADS}..."
export CONFIG="
SET memory_limit='${MEM_LIMIT}';
SET temp_directory='./tmp';
SET threads=${NUM_THREADS};
"

# Process and run SQL files
for sql_file in "${SQL_FILES[@]}"; do
    echo "Processing and running ${sql_file}..."
    envsubst < "sql/${sql_file}" > "tmp/${sql_file}"
    
    # Run with -bail flag to exit on error
    time ${DUCKDB} "${MAIN_DB}" < "tmp/${sql_file}"
    
    # Debug: Check views after setup.sql
    if [ "$sql_file" = "0_setup.sql" ]; then
        echo "Checking views after setup..."
        ${DUCKDB} "${MAIN_DB}" -c "SELECT name FROM sqlite_master WHERE type='view';"
    fi
done

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -f tmp/*.sql

# Run the export process
echo "Running exports using temp tables..."
./export_all.sh

echo "Pipeline completed at: $(date)"
