#!/bin/bash

# Fail fast on setup errors
set -e

# Load environment configuration
set -o allexport
source dot.env
set +o allexport

# Early exit if NO_IMPORT is set
if [ ! -z "${NO_IMPORT+x}" ]; then
    echo "Skipping import process (NO_IMPORT set)"
    exit 0
fi

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

# Ensure export script is executable
chmod +x export_all.sh

echo "Pipeline started at: $(date)"

# Set DuckDB configuration as an environment variable
#echo "Configuring DuckDB with memory_limit=${MEM_LIMIT} and threads=${NUM_THREADS}..."
export CONFIG=$(envsubst < sql/config.sql)

# Process and run SQL files
for sql_file in "${SQL_FILES[@]}"; do
    echo "Processing ${sql_file}..."
    envsubst < "sql/${sql_file}" > "tmp/${sql_file}"
    
    # Execute with error handling
    time ${DUCKDB} "${MAIN_DB}" < "tmp/${sql_file}"
    
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
    AND name IN ('comprehensive_data', 'master_mailing', 'faculty_records', 'course_section_records', 'course_records');
"

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -f tmp/*.sql

# Run export process unless NO_EXPORT is set
if [ -z "${NO_EXPORT+x}" ]; then
    echo "Generating exports..."
    ./export_all.sh
else
    echo "Skipping exports (NO_EXPORT set)"
fi

echo "Pipeline completed at: $(date)"
