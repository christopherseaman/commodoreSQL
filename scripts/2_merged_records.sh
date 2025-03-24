#!/bin/bash

# Exit on any error
set -e

# Step 2: Create merged records by faculty member and by course
# This script creates faculty records, course section records, and course records

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

echo "Step 2.1: Creating faculty records..."
run_with_time "Creating faculty records" "${DUCKDB} \"${MAIN_DB}\" < sql/2_merged_records/faculty_records.sql" ""

echo "Step 2.2: Creating course section records..."
run_with_time "Creating course section records" "${DUCKDB} \"${MAIN_DB}\" < sql/2_merged_records/course_sections.sql" ""

echo "Step 2.3: Creating course records..."
run_with_time "Creating course records" "${DUCKDB} \"${MAIN_DB}\" < sql/2_merged_records/courses.sql" ""

echo "Step 2 completed: Merged records created successfully!"
