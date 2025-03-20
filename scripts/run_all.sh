#!/bin/bash

# Step 4: Save all code in a format that can easily be run for each master file update
# This script runs all steps in sequence

# Make all scripts executable
chmod +x scripts/*.sh

# Load environment variables
set -o allexport
source dot.env
set +o allexport

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

# Create tmp directory if it doesn't exist
mkdir -p tmp

echo "Running all steps for CSV date: ${CSV_DATE}"

# Step 0: Setup, import, and join data
echo "Step 0: Setup, import, and join data..."
./scripts/0_setup.sh "${CSV_DATE}"
if [ $? -ne 0 ]; then
    echo "Error: Step 0 failed"
    exit 1
fi

# Step 1: Create CSV versions of key mailing lists
echo "Step 1: Creating CSV versions of key mailing lists..."
./scripts/1_mailing_lists.sh
if [ $? -ne 0 ]; then
    echo "Error: Step 1 failed"
    exit 1
fi

# Step 2: Create merged records by faculty member and by course
echo "Step 2: Creating merged records by faculty member and by course..."
./scripts/2_merged_records.sh
if [ $? -ne 0 ]; then
    echo "Error: Step 2 failed"
    exit 1
fi

# Step 3: Create CSV versions of key merged records
echo "Step 3: Creating CSV versions of key merged records..."
./scripts/3_export_csv.sh
if [ $? -ne 0 ]; then
    echo "Error: Step 3 failed"
    exit 1
fi

echo "Step 4 completed: All steps executed successfully!"
echo "Output files are in the ${OUTPUT_DIR} directory"
echo ""
echo "To run this process for a new data update, simply update the CSV_DATE in dot.env"
echo "or provide it as an argument: ./scripts/run_all.sh YYYYMMDD"
