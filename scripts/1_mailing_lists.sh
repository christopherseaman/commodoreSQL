#!/bin/bash

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

echo "Step 1.1: Creating master mailing list..."
${DUCKDB} "${MAIN_DB}" < sql/1_mailing_lists/master_mailing.sql
if [ $? -ne 0 ]; then
    echo "Error: Master mailing list creation failed"
    exit 1
fi

echo "Step 1.2: Creating subset mailing lists..."
${DUCKDB} "${MAIN_DB}" < sql/1_mailing_lists/subset_mailings.sql
if [ $? -ne 0 ]; then
    echo "Error: Subset mailing lists creation failed"
    exit 1
fi

echo "Step 1 completed: CSV versions of key mailing lists created successfully!"
