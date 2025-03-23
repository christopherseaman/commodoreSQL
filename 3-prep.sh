#!/bin/bash

# Load environment variables from .env file
set -o allexport
source dot.env
set +o allexport

# Run DuckDB commands using the temporary database
duckdb "$TEMP_DB" -c "
PRAGMA temp_directory='/tmp';       -- Use /tmp for temporary storage
PRAGMA memory_limit='${MEM_LIMIT}'; -- Limit memory usage to ${MEM_LIMIT}
PRAGMA threads=${NUM_THREADS};      -- Limit to 2 threads to reduce resource usage

-- Step 1: Select data from the Parquet file and add the derived column using CASE
CREATE TABLE survey_data AS
SELECT *,
    CASE
        WHEN Period LIKE 'Winter %' THEN substr(Period, -4) || '-1'
        WHEN Period LIKE 'Spring %' THEN substr(Period, -4) || '-2'
        WHEN Period LIKE 'Summer %' THEN substr(Period, -4) || '-3'
        WHEN Period LIKE 'Fall %' THEN substr(Period, -4) || '-4'
        ELSE NULL
    END AS period_sortable
FROM parquet_scan('${SURVEY_DATA}');

-- Step 2: Write the updated data to a new Parquet file
COPY survey_data TO '${PREPARED_DATA}' (FORMAT 'parquet');
" 2>> error.log

# Check if the DuckDB command was successful
if [ $? -ne 0 ]; then
    echo "DuckDB command failed. Check error.log for details."
fi

# Clean up the temporary DuckDB database file
rm -f "$TEMP_DB"