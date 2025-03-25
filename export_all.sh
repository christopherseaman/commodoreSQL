#!/bin/bash

# Load environment variables
set -o allexport
source dot.env
set +o allexport

# Create required directories
mkdir -p tmp output

# Set default for DUCKDB if not defined
DUCKDB=${DUCKDB:-"duckdb"}

echo "Export process started at: $(date)"

# Use the CONFIG environment variable from run.sh
# If not set, create it
if [ -z "${CONFIG+x}" ]; then
    echo "CONFIG not set, creating default configuration..."
    export CONFIG="
    SET memory_limit='${MEM_LIMIT}';
    SET temp_directory='./tmp';
    SET threads=${NUM_THREADS};
    "
fi

echo "Using DuckDB configuration from CONFIG environment variable"

# Get a list of all export SQL files
export_files=($(find sql/exports -name "*.sql" | sort))

# Count total exports
total_exports=${#export_files[@]}
current_export=0
successful_exports=0
failed_exports=0

echo "Found ${total_exports} export files to process"

for export_file in "${export_files[@]}"; do
    # Get the base filename without path and extension
    filename=$(basename "$export_file" .sql)
    export_name="${filename#*_}"
    output_file="${OUTPUT_DIR}/${export_name}.csv"
    
    # Increment counter
    ((current_export++))
    
    echo "===== Exporting ${export_name} (${current_export}/${total_exports}) ====="
    
    # Remove existing file if it exists
    if [ -f "${output_file}" ]; then
        echo "Removing existing file: ${output_file}"
        rm -f "${output_file}"
    fi
    
    # Process the export file with envsubst
    envsubst < "$export_file" > "tmp/${filename}.sql"
    
    # Create the export SQL
    cat > "tmp/${filename}_export.sql" << EOF
${CONFIG}

-- Create temp table
DROP TABLE IF EXISTS temp_export_table;
CREATE TEMPORARY TABLE temp_export_table AS 
$(cat "tmp/${filename}.sql");

-- Get row count
SELECT COUNT(*) AS row_count FROM temp_export_table;

-- Export to CSV
COPY temp_export_table TO '${output_file}' (HEADER, DELIMITER ',');

-- Clean up
DROP TABLE IF EXISTS temp_export_table;
EOF
    
    # Run the export with error handling
    if ${DUCKDB} "${MAIN_DB}" < "tmp/${filename}_export.sql"; then
        echo "✓ Successfully exported ${export_name}"
        ((successful_exports++))
    else
        echo "✗ Failed to export ${export_name}"
        ((failed_exports++))
    fi
    
    # Add a separator for readability
    echo ""
done

# Print summary
echo "===== Export Summary ====="
echo "Total exports: ${total_exports}"
echo "Successful: ${successful_exports}"
echo "Failed: ${failed_exports}"

echo "Output files are in the ${OUTPUT_DIR} directory" 
echo "Export process completed at: $(date)"
