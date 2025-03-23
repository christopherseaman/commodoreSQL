#!/bin/bash

# Exit on any error
set -e

# Debug output
echo "=== Debug Info ==="
echo "Script location: $(readlink -f "$0")"
echo "Current directory: $(pwd)"
echo "Script directory: $(dirname "$(readlink -f "$0")")"
echo "Parent directory: $(dirname "$(dirname "$(readlink -f "$0")")")"
echo "Contents of current directory:"
ls -la
echo "Contents of scripts directory:"
ls -la scripts
echo "=== End Debug Info ==="

# Step 4: Save all code in a format that can easily be run for each master file update
# This script runs all steps in sequence

# Make all scripts executable
chmod +x scripts/*.sh

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Start timing for overall pipeline
PIPELINE_START=$(date +%s)

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) DEBUG=true ;;
        --debug-verbose) DEBUG_VERBOSE=true ;;
        *) CSV_DATE="$1" ;;
    esac
    shift
done

if [ ! -z "${CSV_DATE}" ]; then
    echo "Using CSV date: ${CSV_DATE}"
    # Update the survey CSV path with the new date
    export SURVEY_CSV="csv/bayview_${CSV_DATE}.csv"
else
    echo "Using default CSV date: ${CSV_DATE}"
fi

# Show debug settings
if [ "${DEBUG}" = "true" ]; then
    echo "Debug mode: ON (descriptions at the end)"
fi
if [ "${DEBUG_VERBOSE}" = "true" ]; then
    echo "Verbose debug mode: ON (descriptions at each step)"
fi

# Create required directories
mkdir -p tmp output

# Clean up any temporary files from previous runs
echo "Cleaning up temporary files..."
rm -f tmp/*
rm -f output/*.tmp
rm -f commodore.db.tmp/*

echo "Running all steps for CSV date: ${CSV_DATE}"

# During testing: Delete the database if it exists to start fresh
if [ -f "${MAIN_DB}" ]; then
    echo "Deleting existing database for testing..."
    rm "${MAIN_DB}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to delete existing database"
        exit 1
    else
        echo "Existing database deleted"
    fi
fi

# Function to run a step with proper error handling and time tracking
run_step() {
    local step_num="$1"
    local step_name="$2"
    local script="$3"
    local args="$4"
    
    echo "Step ${step_num}: ${step_name}..."
    
    # Start time tracking
    local start_time=$(date +%s)
    
    # Run the script using full path
    bash "$(dirname "$(readlink -f "$0")")/${script}" ${args} || {
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        echo "Error: Step ${step_num} failed after ${minutes}m ${seconds}s"
        exit 1
    }
    
    # End time tracking
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # Save step timing to the log file
    echo "Step ${step_num} (${step_name}): ${minutes}m ${seconds}s" >> "${OUTPUT_DIR}/pipeline_timing.log"
    echo "Step ${step_num} completed in ${minutes}m ${seconds}s"
}

# Initialize timing log
echo "Pipeline started at: $(date)" > "${OUTPUT_DIR}/pipeline_timing.log"

# Step 0: Setup, import, and join data
run_step "0" "Setup, import, and join data" "0_setup.sh" "${CSV_DATE}"

# Step 1: Create CSV versions of key mailing lists
run_step "1" "Creating CSV versions of key mailing lists" "1_mailing_lists.sh" ""

# Step 2: Create merged records by faculty member and by course
run_step "2" "Creating merged records by faculty member and by course" "2_merged_records.sh" ""

# Step 3: Create CSV versions of key merged records
run_step "3" "Creating CSV versions of key merged records" "3_export_csv.sh" ""

# Clean up backup if everything succeeded
if [ -f "${MAIN_DB}.bak" ]; then
    rm "${MAIN_DB}.bak"
fi

# Final cleanup
echo "Cleaning up temporary files..."
rm -f tmp/*
rm -f output/*.tmp
rm -f commodore.db.tmp/*

# Calculate and log total pipeline time
PIPELINE_END=$(date +%s)
TOTAL_DURATION=$((PIPELINE_END - PIPELINE_START))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
TOTAL_SECONDS=$((TOTAL_DURATION % 60))

echo "" >> "${OUTPUT_DIR}/pipeline_timing.log"
echo "Total pipeline duration: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s" >> "${OUTPUT_DIR}/pipeline_timing.log"
echo "Pipeline completed at: $(date)" >> "${OUTPUT_DIR}/pipeline_timing.log"

echo "Step 4 completed: All steps executed successfully!"
echo "Output files are in the ${OUTPUT_DIR} directory"
echo "Pipeline completed in ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s"
echo "Detailed timing information saved to ${OUTPUT_DIR}/pipeline_timing.log"
echo ""
echo "To run this process for a new data update, simply update the CSV_DATE in dot.env"
echo "or provide it as an argument: ./scripts/run_all.sh YYYYMMDD"
