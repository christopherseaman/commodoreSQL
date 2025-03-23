#!/bin/bash

# Load environment variables from .env file
set -o allexport
source dot.env
set +o allexport

# Output directory for Parquet files
mkdir -p "$PARQUET_DIRECTORY"

# Check if a CSV file argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <csv_file>"
  exit 1
fi

# Get the CSV file from the first argument
CSV_FILE="$1"

# Extract the base filename without the extension (lowercase, drop suffix, periods to underscores)
BASE_NAME=$(basename "$CSV_FILE" | sed 's/\(.*\)\..*/\1/' | tr '[:upper:]' '[:lower:]' | tr '.' '_')

# Set the output Parquet file path
PARQUET_FILE="$PARQUET_DIRECTORY/$BASE_NAME.parquet"

# Remove the Parquet file if it already exists
if [ -f "$PARQUET_FILE" ]; then
  rm "$PARQUET_FILE"
fi

# Run DuckDB command to convert CSV to Parquet
duckdb <<SQL
PRAGMA enable_progress_bar=true;

-- Copy CSV to Parquet
COPY (
    SELECT *
    FROM read_csv('$CSV_FILE', 
        header=true, 
        delim=',', 
        nullstr=['N/A', '', 'Not applicable'])
)
TO '$PARQUET_FILE' (FORMAT PARQUET, ROW_GROUP_SIZE 1000000);
SQL

echo "Converted $CSV_FILE to $PARQUET_FILE"