#!/bin/bash

# Step 2: Create merged records by faculty member and by course
# This script creates faculty records, course section records, and course records

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Set default for DUCKDB if not defined
DUCKDB=${DUCKDB:-"duckdb"}

echo "Step 2.1: Creating faculty records..."
${DUCKDB} "${MAIN_DB}" < sql/2_merged_records/faculty_records.sql
if [ $? -ne 0 ]; then
    echo "Error: Faculty records creation failed"
    exit 1
fi

echo "Step 2.2: Creating course section records..."
${DUCKDB} "${MAIN_DB}" < sql/2_merged_records/course_sections.sql
if [ $? -ne 0 ]; then
    echo "Error: Course section records creation failed"
    exit 1
fi

echo "Step 2.3: Creating course records..."
${DUCKDB} "${MAIN_DB}" < sql/2_merged_records/courses.sql
if [ $? -ne 0 ]; then
    echo "Error: Course records creation failed"
    exit 1
fi

echo "Step 2 completed: Merged records created successfully!"
