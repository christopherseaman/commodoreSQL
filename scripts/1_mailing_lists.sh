#!/bin/bash

# Exit on any error
set -e

# Step 1: Create CSV versions of key mailing lists for immediate use
# This script creates master mailing list and subset mailing lists

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Create tmp directory if it doesn't exist
mkdir -p tmp

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

echo "Step 1.1: Creating master mailing list..."
run_with_time "Creating master mailing list" "${DUCKDB} \"${MAIN_DB}\" < sql/1_mailing_lists/master_mailing.sql" ""

echo "Step 1.2: Creating subset mailing lists..."
run_with_time "Creating subset mailing lists" "${DUCKDB} \"${MAIN_DB}\" < sql/1_mailing_lists/subset_mailings.sql" ""

echo "Step 1 completed: CSV versions of key mailing lists created successfully!"
