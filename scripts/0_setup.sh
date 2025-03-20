#!/bin/bash

# Step 0: Setup, import, and join data
# This script imports CSV files and builds the comprehensive database

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Create output and tmp directories if they don't exist
mkdir -p "${OUTPUT_DIR}" tmp

# Always use the CSV paths from dot.env
echo "Survey CSV path: ${SURVEY_CSV}"

# Check if the survey CSV file exists
if [ ! -f "${SURVEY_CSV}" ]; then
    # If the file doesn't exist, check if it's a compressed file without the extension
    SURVEY_CSV_BASE=$(echo "${SURVEY_CSV}" | sed 's/\.[^.]*$//')
    if [ -f "${SURVEY_CSV_BASE}" ]; then
        export SURVEY_CSV="${SURVEY_CSV_BASE}"
        echo "Found uncompressed version of CSV: ${SURVEY_CSV}"
    else
        echo "Error: Survey CSV file not found: ${SURVEY_CSV}"
        echo "Also checked for uncompressed version: ${SURVEY_CSV_BASE}"
        exit 1
    fi
fi

# Check if IPEDS and optout files exist
if [ ! -f "${IPEDS_CSV}" ]; then
    echo "Error: IPEDS CSV file not found: ${IPEDS_CSV}"
    exit 1
fi

if [ ! -f "${OPTOUT_CSV}" ]; then
    echo "Error: Opt-out CSV file not found: ${OPTOUT_CSV}"
    exit 1
fi

# Extract table names from filenames (lowercase, no extension, replace periods with underscores)
export SURVEY_TABLE=$(basename "${SURVEY_CSV}" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | tr '.' '_')
export IPEDS_TABLE=$(basename "${IPEDS_CSV}" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | tr '.' '_')
export OPTOUT_TABLE=$(basename "${OPTOUT_CSV}" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | tr '.' '_')

echo "Using table names:"
echo "  Survey table: ${SURVEY_TABLE}"
echo "  IPEDS table: ${IPEDS_TABLE}"
echo "  Opt-out table: ${OPTOUT_TABLE}"

# Set default for DUCKDB if not defined
DUCKDB=${DUCKDB:-"duckdb"}

echo "Step 0.1: Importing CSV files..."
# Process SQL files with environment variables
envsubst < sql/0_setup/config.sql > tmp/config_with_vars.sql
envsubst < sql/0_setup/import.sql > tmp/import_with_vars.sql

# Run DuckDB commands using the SQL files
echo "  Configuring DuckDB..."
${DUCKDB} "${MAIN_DB}" < tmp/config_with_vars.sql
if [ $? -ne 0 ]; then
    echo "Error: DuckDB configuration failed"
    rm tmp/config_with_vars.sql tmp/import_with_vars.sql
    exit 1
fi

echo "  Importing CSV files..."
${DUCKDB} "${MAIN_DB}" < tmp/import_with_vars.sql
if [ $? -ne 0 ]; then
    echo "Error: CSV import failed"
    rm tmp/config_with_vars.sql tmp/import_with_vars.sql
    exit 1
fi

# Verify import
echo "  Verifying import..."
${DUCKDB} "${MAIN_DB}" < sql/0_setup/verify.sql
if [ $? -ne 0 ]; then
    echo "Error: Import verification failed"
    rm tmp/config_with_vars.sql tmp/import_with_vars.sql
    exit 1
fi

# Describe import if DEBUG_VERBOSE is true
if [ "${DEBUG_VERBOSE}" = "true" ]; then
    echo "  Describing imported data (verbose mode)..."
    ${DUCKDB} "${MAIN_DB}" < sql/0_setup/describe_import.sql > "${OUTPUT_DIR}/import_description.txt"
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to generate import description"
    else
        echo "  Import description saved to ${OUTPUT_DIR}/import_description.txt"
    fi
fi

# Clean up temporary files
rm tmp/config_with_vars.sql tmp/import_with_vars.sql

echo "Step 0.2: Building comprehensive database (joining data)..."
echo "  Running joins and transformations..."
${DUCKDB} "${MAIN_DB}" < sql/0_setup/comprehensive.sql
if [ $? -ne 0 ]; then
    echo "Error: Comprehensive database build failed"
    exit 1
fi

# Verify comprehensive database
echo "  Verifying comprehensive database..."
${DUCKDB} "${MAIN_DB}" < sql/0_setup/verify.sql

# Describe comprehensive database if DEBUG_VERBOSE is true
if [ "${DEBUG_VERBOSE}" = "true" ]; then
    echo "  Describing comprehensive database (verbose mode)..."
    ${DUCKDB} "${MAIN_DB}" < sql/0_setup/describe_comprehensive.sql > "${OUTPUT_DIR}/comprehensive_description.txt"
    echo "  Comprehensive database description saved to ${OUTPUT_DIR}/comprehensive_description.txt"
fi

# Generate description at the end if DEBUG is true
if [ "${DEBUG}" = "true" ] || [ "${DEBUG_VERBOSE}" = "true" ]; then
    if [ "${DEBUG}" = "true" ] && [ "${DEBUG_VERBOSE}" != "true" ]; then
        echo "Generating detailed descriptions..."
        echo "  Describing imported data..."
        ${DUCKDB} "${MAIN_DB}" < sql/0_setup/describe_import.sql > "${OUTPUT_DIR}/import_description.txt"
        echo "  Import description saved to ${OUTPUT_DIR}/import_description.txt"
        
        echo "  Describing comprehensive database..."
        ${DUCKDB} "${MAIN_DB}" < sql/0_setup/describe_comprehensive.sql > "${OUTPUT_DIR}/comprehensive_description.txt"
        echo "  Comprehensive database description saved to ${OUTPUT_DIR}/comprehensive_description.txt"
    fi
    
    # Show the results to the user
    echo ""
    echo "Showing sample results:"
    ${DUCKDB} "${MAIN_DB}" -c "SELECT * FROM comprehensive_data LIMIT 5;"
fi

echo "Step 0 completed: Setup, import, and join completed successfully!"
