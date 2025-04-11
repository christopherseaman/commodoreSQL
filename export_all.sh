#!/bin/bash

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Create required directories
mkdir -p tmp output/exports

# Set CONFIG if not already set
if [ -z "${CONFIG+x}" ]; then
    echo "Loading DuckDB configuration from sql/config.sql..."
    export CONFIG=$(envsubst < sql/config.sql)
fi

# Count total exports
total_exports=$(find sql/exports -name "*.sql" | wc -l)
current_export=0

# Function to process a single export
process_export() {
    local input_file=$1
    local output_file=$2
    local export_name=$(basename "$input_file" .sql)
    
    # Increment counter
    ((current_export++))
    
    echo "===== Processing $export_name ($current_export/$total_exports) ====="
    
    # Create temporary SQL file with configuration
    cat > "tmp/exports/$export_name.sql" << EOF
-- Load DuckDB configuration
${CONFIG}

-- Create temporary table from the export query
CREATE OR REPLACE TEMP TABLE export_table AS
$(cat "$input_file");

-- Export to CSV using native COPY command
COPY export_table TO '$output_file' (
    HEADER,
    DELIMITER ','
);

-- Clean up
DROP TABLE IF EXISTS export_table;
EOF
    
    # Process the export
    nice -n 19 duckdb commodore.db < "tmp/exports/$export_name.sql"
}

# Process each export file
for export_file in sql/exports/*.sql; do
    if [ -f "$export_file" ]; then
        export_name=$(basename "$export_file" .sql)
        output_file="output/exports/${export_name}.csv"
        process_export "$export_file" "$output_file"
    fi
done

echo "All exports completed!"