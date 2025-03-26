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
    output_file="${OUTPUT_DIR}/${export_name}.csv"
    
    ((current_export++))
    echo "===== Exporting ${export_name} (${current_export}/${total_exports}) ====="
    
    # Process the export file
    envsubst < "$export_file" > "tmp/${filename}.sql"
    
    # Create chunked export SQL
    cat > "tmp/${filename}_export.sql" << EOF
${CONFIG}

-- Export in chunks using period_sortable
COPY (
    SELECT * FROM ($(cat "tmp/${filename}.sql"))
    WHERE period_sortable >= '2020-1' AND period_sortable < '2022-1'
) TO '${output_file%.csv}_2020_2021.csv' (HEADER, DELIMITER ',', CHUNK_SIZE 50000);

COPY (
    SELECT * FROM ($(cat "tmp/${filename}.sql"))
    WHERE period_sortable >= '2022-1' AND period_sortable < '2024-1'
) TO '${output_file%.csv}_2022_2023.csv' (HEADER, DELIMITER ',', CHUNK_SIZE 50000);

COPY (
    SELECT * FROM ($(cat "tmp/${filename}.sql"))
    WHERE period_sortable < '2020-1' OR period_sortable >= '2024-1' OR period_sortable IS NULL
) TO '${output_file%.csv}_other.csv' (HEADER, DELIMITER ',', CHUNK_SIZE 50000);
EOF

    if ${DUCKDB} "${MAIN_DB}" < "tmp/${filename}_export.sql"; then
        echo "✓ Successfully exported ${export_name} in chunks"
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