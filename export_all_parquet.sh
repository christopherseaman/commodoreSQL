#!/bin/bash

# Load environment configuration
set -o allexport
source dot.env
set +o allexport

# Prepare output directories
mkdir -p tmp output

echo "Export process started at: $(date)"

# Discover and process SQL export files
export_files=($(find sql/exports -name "*.sql" | sort))
total_exports=${#export_files[@]}
current_export=0
successful_exports=0
failed_exports=0

echo "Found ${total_exports} export files to process"

for export_file in "${export_files[@]}"; do
    filename=$(basename "$export_file" .sql)
    export_name="${filename#*_}"
    output_file="${OUTPUT_DIR}/${export_name}.parquet"
    
    ((current_export++))
    echo "===== Exporting ${export_name} (${current_export}/${total_exports}) ====="
    
    # Prepare export file with environment variables
    envsubst < "$export_file" > "tmp/${filename}.sql"
    
    # Generate Parquet export SQL with optimized settings
    cat > "tmp/${filename}_export.sql" << EOF
${CONFIG}

-- Export data to compressed Parquet format
COPY (
    SELECT * FROM ($(cat "tmp/${filename}.sql"))
) TO '${output_file}' (
    FORMAT PARQUET,
    ROW_GROUP_SIZE 100000,
    COMPRESSION 'ZSTD'
);
EOF

    # Execute export and track results
    if ${DUCKDB} "${MAIN_DB}" < "tmp/${filename}_export.sql"; then
        echo "✓ Successfully exported ${export_name} to parquet"
        ((successful_exports++))
    else
        echo "✗ Failed to export ${export_name}"
        ((failed_exports++))
    fi
    
    echo ""
done

# Report export process summary
echo "===== Export Summary ====="
echo "Total exports: ${total_exports}"
echo "Successful: ${successful_exports}"
echo "Failed: ${failed_exports}"
