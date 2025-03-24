#!/bin/bash

# Exit on any error
set -e

# Step 3: Create CSV versions of key merged records
# This script exports all tables to CSV format

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

echo "Step 3: Exporting tables to CSV..."

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Use envsubst to replace variables in the SQL file
envsubst < sql/3_export_csv/export.sql > tmp/export_with_vars.sql

# Start time tracking for the entire export process
start_time=$(date +%s)

run_with_time "Exporting tables to CSV" "${DUCKDB} \"${MAIN_DB}\" < tmp/export_with_vars.sql" ""
rm tmp/export_with_vars.sql

# End time tracking for the entire export process
end_time=$(date +%s)
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))
echo "Total export time: ${minutes}m ${seconds}s"

echo "Step 3 completed: CSV exports created successfully!"
echo "Output files are in the ${OUTPUT_DIR} directory"
