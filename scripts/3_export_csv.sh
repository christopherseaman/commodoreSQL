#!/bin/bash

# Step 3: Create CSV versions of key merged records
# This script exports all tables to CSV format

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Set default for DUCKDB if not defined
DUCKDB=${DUCKDB:-"duckdb"}

echo "Step 3: Exporting tables to CSV..."

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Use envsubst to replace variables in the SQL file
envsubst < sql/3_export_csv/export.sql > tmp/export_with_vars.sql
${DUCKDB} "${MAIN_DB}" < tmp/export_with_vars.sql
if [ $? -ne 0 ]; then
    echo "Error: Export failed"
    exit 1
fi
rm tmp/export_with_vars.sql

echo "Step 3 completed: CSV exports created successfully!"
echo "Output files are in the ${OUTPUT_DIR} directory"
