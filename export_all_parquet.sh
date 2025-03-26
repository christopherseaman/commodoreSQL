#!/bin/bash

# Load environment variables
set -o allexport
source dot.env
set +o allexport

mkdir -p tmp output

echo "Export process started at: $(date)"

# Get list of export SQL files
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
    
    # Process the export file
    envsubst < "$export_file" > "tmp/${filename}.sql"
    
    # Create parquet export SQL with row groups
    cat > "tmp/${filename}_export.sql" << EOF
${CONFIG}

-- Export to parquet with row groups
COPY (
    SELECT * FROM ($(cat "tmp/${filename}.sql"))
) TO '${output_file}' (
    FORMAT PARQUET,
    ROW_GROUP_SIZE 100000,
    COMPRESSION 'ZSTD'
);
EOF

    if ${DUCKDB} "${MAIN_DB}" < "tmp/${filename}_export.sql"; then
        echo "✓ Successfully exported ${export_name} to parquet"
        ((successful_exports++))
    else
        echo "✗ Failed to export ${export_name}"
        ((failed_exports++))
    fi
    
    echo ""
done

echo "===== Export Summary ====="
echo "Total exports: ${total_exports}"
echo "Successful: ${successful_exports}"
echo "Failed: ${failed_exports}" 