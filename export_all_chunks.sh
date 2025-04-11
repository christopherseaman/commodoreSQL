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
    output_file="${OUTPUT_DIR}/${export_name}.csv"
    
    ((current_export++))
    echo "===== Exporting ${export_name} (${current_export}/${total_exports}) ====="
    
    # Prepare export file with environment variables
    envsubst < "$export_file" > "tmp/${filename}.sql"
    
    # Generate chunked export SQL by time periods
    cat > "tmp/${filename}_export.sql" << EOF
${CONFIG}

-- Export data in time-based chunks
COPY (
    SELECT * FROM ($(cat "tmp/${filename}.sql"))
    WHERE period_sortable >= '2020-1' AND period_sortable < '2022-1'
) TO '${output_file%.csv}_2020_2021.csv' WITH (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM ($(cat "tmp/${filename}.sql"))
    WHERE period_sortable >= '2022-1' AND period_sortable < '2024-1'
) TO '${output_file%.csv}_2022_2023.csv' WITH (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM ($(cat "tmp/${filename}.sql"))
    WHERE period_sortable < '2020-1' OR period_sortable >= '2024-1' OR period_sortable IS NULL
) TO '${output_file%.csv}_other.csv' WITH (HEADER, DELIMITER ',');
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
