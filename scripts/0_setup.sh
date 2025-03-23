#!/bin/bash

# Exit on any error
set -e

# Step 0: Setup, import, and join data
# This script imports CSV files and creates the comprehensive database

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Set default for DUCKDB if not defined
DUCKDB=${DUCKDB:-"duckdb"}

# Function to track time for a command
run_with_time() {
    local description="$1"
    local command="$2"
    local args="$3"
    
    echo "  ${description}..."
    
    # Start time tracking
    local start_time=$(date +%s)
    
    # Run the command
    eval "${command} ${args}" || {
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        echo "  Error: ${description} failed after ${minutes}m ${seconds}s"
        return 1
    }
    
    # End time tracking
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo "  ${description} completed in ${minutes}m ${seconds}s"
    return 0
}

# Extract table names from filenames (lowercase, no extension, replace periods with underscores)
export SURVEY_TABLE=$(basename "${SURVEY_CSV}" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | tr '.' '_')
export IPEDS_TABLE=$(basename "${IPEDS_CSV}" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | tr '.' '_')
export OPTOUT_TABLE=$(basename "${OPTOUT_CSV}" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | tr '.' '_')

echo "Using table names:"
echo "  Survey table: ${SURVEY_TABLE}"
echo "  IPEDS table: ${IPEDS_TABLE}"
echo "  Opt-out table: ${OPTOUT_TABLE}"

echo "Step 0.1: Importing CSV files..."
# Process SQL files with environment variables
envsubst < sql/0_setup/config.sql > tmp/config_with_vars.sql
envsubst < sql/0_setup/import.sql > tmp/import_with_vars.sql

# Run DuckDB commands using the SQL files
run_with_time "Configuring DuckDB" "${DUCKDB} \"${MAIN_DB}\" < tmp/config_with_vars.sql" ""
run_with_time "Importing CSV files" "${DUCKDB} \"${MAIN_DB}\" < tmp/import_with_vars.sql" ""
run_with_time "Verifying import" "${DUCKDB} \"${MAIN_DB}\" < sql/0_setup/verify.sql" ""

# Describe import if DEBUG_VERBOSE is true
if [ "${DEBUG_VERBOSE}" = "true" ]; then
    echo "  Describing imported data (verbose mode)..."
    ${DUCKDB} "${MAIN_DB}" < sql/0_setup/describe_import.sql > "${OUTPUT_DIR}/import_description.txt"
    echo "  Import description saved to ${OUTPUT_DIR}/import_description.txt"
fi

# Clean up temporary files
rm tmp/config_with_vars.sql tmp/import_with_vars.sql

echo "Step 0.2: Building comprehensive database (joining data)..."
run_with_time "Running joins and transformations" "${DUCKDB} \"${MAIN_DB}\" < sql/0_setup/comprehensive.sql" ""
run_with_time "Verifying comprehensive database" "${DUCKDB} \"${MAIN_DB}\" < sql/0_setup/verify.sql" ""

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
