-- Step 0: Setup and Import
-- This script:
-- 1. Configures DuckDB settings
-- 2. Imports CSV files
-- 3. Creates comprehensive database with merged data
-- 4. Creates standardized date field (YYYY-N format)

-- Configure DuckDB settings
SET memory_limit='8GB';
SET temp_directory='./tmp';
SET threads=4;

-- Import CSV files
BEGIN TRANSACTION;

-- Drop existing objects if they exist
DROP VIEW IF EXISTS comprehensive_data;
DROP VIEW IF EXISTS survey_data;
DROP VIEW IF EXISTS ipeds_view;
DROP VIEW IF EXISTS optout_view;
DROP TABLE IF EXISTS ${SURVEY_TABLE};
DROP TABLE IF EXISTS ${IPEDS_TABLE};
DROP TABLE IF EXISTS ${OPTOUT_TABLE};

-- Import survey data
CREATE TABLE ${SURVEY_TABLE} AS
SELECT * FROM read_csv('${SURVEY_CSV}',
    compression='gzip',
    header=true,
    delim=',',
    quote='"',
    escape='"',
    nullstr=['N/A', '', 'Not applicable']);

-- Convert numeric fields
ALTER TABLE ${SURVEY_TABLE} ALTER "Enrollments" TYPE INTEGER USING TRY_CAST("Enrollments" AS INTEGER);

-- Import IPEDS data
CREATE TABLE ${IPEDS_TABLE} AS
SELECT * FROM read_csv('${IPEDS_CSV}', 
    compression='none',
    header=true, 
    delim=',', 
    nullstr=['N/A', '', 'Not applicable']);

-- Convert numeric fields
ALTER TABLE ${IPEDS_TABLE} ALTER sector TYPE INTEGER USING TRY_CAST(sector AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER iclevel TYPE INTEGER USING TRY_CAST(iclevel AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER control TYPE INTEGER USING TRY_CAST(control AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER instsize TYPE INTEGER USING TRY_CAST(instsize AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER efydetot_tot_22 TYPE INTEGER USING TRY_CAST(efydetot_tot_22 AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER efyde_tot_22 TYPE INTEGER USING TRY_CAST(efyde_tot_22 AS INTEGER);

-- Import opt-out data
CREATE TABLE ${OPTOUT_TABLE} AS
SELECT * FROM read_csv('${OPTOUT_CSV}', 
    compression='none',
    header=true, 
    delim=',', 
    nullstr=['N/A', '', 'Not applicable']);

-- Create base views first
CREATE VIEW survey_data AS SELECT * FROM ${SURVEY_TABLE};
CREATE VIEW ipeds_view AS SELECT * FROM ${IPEDS_TABLE};
CREATE VIEW optout_view AS SELECT * FROM ${OPTOUT_TABLE};

-- Then create the dependent view
CREATE VIEW comprehensive_data AS
WITH survey_with_period AS (
    -- Convert "Fall 2023" to "2023-4" format
    SELECT *,
        CASE
            WHEN "Period" LIKE 'Winter %' AND LENGTH(TRIM(substr("Period", -4))) = 4 
                THEN substr("Period", -4) || '-1'
            WHEN "Period" LIKE 'Spring %' AND LENGTH(TRIM(substr("Period", -4))) = 4 
                THEN substr("Period", -4) || '-2'
            WHEN "Period" LIKE 'Summer %' AND LENGTH(TRIM(substr("Period", -4))) = 4 
                THEN substr("Period", -4) || '-3'
            WHEN "Period" LIKE 'Fall %' AND LENGTH(TRIM(substr("Period", -4))) = 4 
                THEN substr("Period", -4) || '-4'
            ELSE NULL
        END AS period_sortable
    FROM survey_data
    WHERE "Period" IS NOT NULL
)
SELECT 
    s.*,  -- All survey fields
    -- IPEDS institutional information
    i.instnm,      -- Institution name
    i.sector,      -- Institution sector
    i.iclevel,     -- Institution level
    i.control,     -- Control type
    i.instsize,    -- Institution size
    i.efydetot_tot_22,  -- Total enrollment
    i.efyde_tot_22,     -- Degree-seeking enrollment
    i.typeinst,    -- Institution type
    i.insttype,    -- Detailed institution type
    -- Opt-out status
    CASE WHEN o.Emails IS NOT NULL THEN 1 ELSE 0 END AS is_opted_out,
    o.Source AS opt_out_source
FROM survey_with_period s
LEFT JOIN ipeds_view i ON s."IPED ID" = i.unitid
LEFT JOIN optout_view o ON LOWER(TRIM(s."E-Mail")) = LOWER(TRIM(o.Emails));

COMMIT;

-- Run ANALYZE to update statistics
ANALYZE ${SURVEY_TABLE};
ANALYZE ${IPEDS_TABLE};
ANALYZE ${OPTOUT_TABLE};
