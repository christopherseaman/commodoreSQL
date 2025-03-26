#!/bin/bash

# Load environment configuration
set -o allexport
source dot.env
set +o allexport

# Prepare output directories
mkdir -p tmp/exports output

echo "Export process started at: $(date)"

# Pre-process all export SQL files
echo "Pre-processing export SQL files..."
for export_file in sql/exports/*.sql; do
    filename=$(basename "$export_file")
    envsubst < "$export_file" > "tmp/exports/${filename}"
done

# Discover and process SQL export files
export_files=($(find tmp/exports -name "*.sql" | sort))
total_exports=${#export_files[@]}
current_export=0
successful_exports=0
failed_exports=0

echo "Found ${total_exports} export files to process"

for export_file in "${export_files[@]}"; do
    filename=$(basename "$export_file" .sql)
    export_name="${filename#*_}"
    output_file="${OUTPUT_DIR}/${export_name}"
    
    ((current_export++))
    echo "===== Exporting ${export_name} (${current_export}/${total_exports}) ====="
    
    # Generate export SQL with partitioning
    cat > "tmp/${filename}_export.sql" << EOF
${CONFIG}
SET partitioned_write_max_open_files = 50;
COPY ($(grep -v '^--' "$export_file" | grep -v '^$'))
TO '${output_file}' (HEADER, DELIMITER ',', PARTITION_BY (period_sortable));
EOF

    # Execute export and track results
    export_log="tmp/${filename}_export.log"
    if ${DUCKDB} "${MAIN_DB}" < "tmp/${filename}_export.sql" 2>&1 | tee "$export_log"; then
        echo "✓ Successfully exported ${export_name} in chunks"
        ((successful_exports++))
    else
        echo "✗ Failed to export ${export_name}"
        echo "Error details in: $export_log"
        cat "$export_log"
        ((failed_exports++))
    fi
    
    echo ""
done

# Check if any exports failed and exit with appropriate status
if [ $failed_exports -gt 0 ]; then
    echo "ERROR: ${failed_exports} export(s) failed. Check log files in tmp/ directory."
    exit 1
fi

# Report export process summary
echo "===== Export Summary ====="
echo "Total exports: ${total_exports}"
echo "Successful: ${successful_exports}"
echo "Failed: ${failed_exports}"
