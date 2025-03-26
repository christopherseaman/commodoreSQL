#!/bin/bash

# Fail fast on setup errors
set -e

# Load environment configuration
set -o allexport
source dot.env
set +o allexport


# Configure DuckDB runtime settings
export CONFIG=$(envsubst < sql/config.sql)

# Define default SQL processing sequence
if [ -z "${SQL_FILES+x}" ]; then
    SQL_FILES=(
        "0_setup.sql"
        "1_mailing_lists.sql"
        "2_merged_records.sql"
    )
fi

# Validate SQL files exist
for sql_file in "${SQL_FILES[@]}"; do
    if [ ! -f "sql/${sql_file}" ]; then
        echo "Error: SQL file sql/${sql_file} not found"
        exit 1
    fi
done

# Prepare output directories
mkdir -p tmp output

# Set default DuckDB executable
DUCKDB=${DUCKDB:-"duckdb"}

echo "Pipeline started at: $(date)"

# Execute SQL files in sequence
for sql_file in "${SQL_FILES[@]}"; do
    echo "Processing ${sql_file}..."
    envsubst < "sql/${sql_file}" > "tmp/${sql_file}"
    
    # Execute with error handling
    time ${DUCKDB} "${MAIN_DB}" < "tmp/${sql_file}"
done

# Remove temporary files
echo "Cleaning temporary files..."
rm -f tmp/*.sql

# Run export process unless NO_EXPORT is set
if [ -z "${NO_EXPORT+x}" ]; then
    echo "Generating exports..."
    ./export_all.sh
else
    echo "Skipping exports (NO_EXPORT set)"
fi

echo "Pipeline completed at: $(date)"
