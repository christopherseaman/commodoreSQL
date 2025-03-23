#! /bin/bash

# Load environment variables from .env file
set -o allexport
source dot.env
set +o allexport

# Add headers to the CSV file
echo "table_name,column_name,column_type,extra" > "$DESCRIBE_CSV"

# Loop through each Parquet file
for PARQUET_FILE in "$PARQUET_DIRECTORY"/*.parquet; do
    BASE_NAME=$(basename "$PARQUET_FILE" | sed 's/\(.*\)\..*/\1/' | tr '[:upper:]' '[:lower:]')
    
    # Use a temporary file for DuckDB output
    TEMP_FILE=$(mktemp)
    
    # Execute DuckDB command and write to the temporary file
    duckdb -c "
        PRAGMA enable_progress_bar=true;
        COPY (
            SELECT '$BASE_NAME' AS table_name, column_name, column_type, extra
            FROM (DESCRIBE SELECT * FROM parquet_scan('$PARQUET_FILE'))
        ) TO '$TEMP_FILE' (DELIMITER ',', HEADER FALSE);
    " 2>>error.log

    # Append the contents of the temporary file to the main CSV
    cat "$TEMP_FILE" >> "$DESCRIBE_CSV"
    
    # Remove the temporary file
    rm "$TEMP_FILE"
done