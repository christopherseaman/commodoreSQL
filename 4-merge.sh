#!/bin/bash

# Load environment variables from .env file
set -o allexport
source dot.env
set +o allexport

# Run DuckDB commands using the temporary database
duckdb "$TEMP_DB" <<EOF
    PRAGMA temp_directory='/tmp';       -- Use /tmp for temporary storage
	PRAGMA memory_limit='${MEM_LIMIT}'; -- Limit memory usage to ${MEM_LIMIT}
	PRAGMA threads=${NUM_THREADS};      -- Limit to 2 threads to reduce resource usage

	-- Step 1: Join!
	CREATE TABLE merge_iped AS (
		SELECT b.*
			, i.instnm
			, i.sector
			, i.iclevel
			, i.control
			, i.instsize
			, i.efydetot_tot_22
			, i.efyde_tot_22
			, i.typeinst
			, i.insttype
		FROM '${PREPARED_DATA}' b
		LEFT JOIN '${IPEDS_DATA}' i
		ON b."IPED ID" = i.unitid
	);

	CREATE TABLE merge_optout AS (
		SELECT m.*
			, o.Source
		FROM merge_iped m
		LEFT JOIN '${OPTOUT_DATA}' o
		ON LOWER(TRIM(m."E-Mail")) = LOWER(TRIM(o.Emails))
	);

	-- Step 2: Write the merged data to parquet
	COPY merge_optout TO '${MERGED_DATA}' (FORMAT 'parquet');
EOF

# Clean up the temporary DuckDB database file
rm -f "$TEMP_DB"