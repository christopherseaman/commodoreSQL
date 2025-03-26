-- Step 0: Setup and Import
-- This script:
-- 1. Imports CSV files
-- 2. Creates comprehensive database with merged data
-- 3. Creates standardized date field (YYYY-N format)

${CONFIG}

-- Import CSV files
BEGIN TRANSACTION;

-- Drop existing objects if they exist
DROP TABLE IF EXISTS comprehensive_data;
DROP TABLE IF EXISTS survey_data;
DROP TABLE IF EXISTS ipeds_view;
DROP TABLE IF EXISTS optout_view;
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

-- Clean/derive columns in the big table
UPDATE ${SURVEY_TABLE} 
SET "E-Mail" = LOWER(TRIM("E-Mail"))
WHERE "E-Mail" IS NOT NULL;

-- Add period_sortable column during creation
ALTER TABLE ${SURVEY_TABLE} 
    ADD COLUMN period_sortable VARCHAR AS (
        CASE
            WHEN "Period" LIKE 'Winter %' THEN substr("Period", -4) || '-1'
            WHEN "Period" LIKE 'Spring %' THEN substr("Period", -4) || '-2'
            WHEN "Period" LIKE 'Summer %' THEN substr("Period", -4) || '-3'
            WHEN "Period" LIKE 'Fall %' THEN substr("Period", -4) || '-4'
            ELSE NULL
        END
    );

-- Convert numeric fields
ALTER TABLE ${SURVEY_TABLE} ALTER "Enrollments" TYPE INTEGER USING TRY_CAST("Enrollments" AS INTEGER);

-- Compress high-cardinality string columns
ALTER TABLE ${SURVEY_TABLE} ALTER "School" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "Department" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "Course Title" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "Publisher" SET COMPRESSION 'DICTIONARY';

-- Partition by most frequent filter/join columns
ALTER TABLE ${SURVEY_TABLE} PARTITION BY (period_sortable);

-- Index key columns used in joins, filters, and sorts
CREATE INDEX idx_survey_email ON ${SURVEY_TABLE} ("E-Mail");
CREATE INDEX idx_survey_ipedid ON ${SURVEY_TABLE} ("IPED ID");
CREATE INDEX idx_survey_state ON ${SURVEY_TABLE} ("State");
CREATE INDEX idx_survey_period ON ${SURVEY_TABLE} (period_sortable);
CREATE INDEX idx_survey_course ON ${SURVEY_TABLE} ("Course Number", "Section", "Course Title");

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

-- Normalize email directly in the imported table
UPDATE ${OPTOUT_TABLE}
SET "Emails" = LOWER(TRIM("Emails"))
WHERE "Emails" IS NOT NULL;

-- Add compression
ALTER TABLE ${SURVEY_TABLE} ALTER "Instructor" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "School" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "Course Title" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "Publisher" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "Department" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "State" SET COMPRESSION 'DICTIONARY';
ALTER TABLE ${SURVEY_TABLE} ALTER "Period" SET COMPRESSION 'DICTIONARY';

-- Optimize IPEDS data similarly
CREATE TABLE ipeds_view AS 
SELECT *,
    -- Add any derived columns used in joins/filters
    CAST(unitid AS VARCHAR) AS unitid_str
FROM ${IPEDS_TABLE}
PARTITION BY (sector, control);  -- Partition by common filter columns

-- Compress string columns
ALTER TABLE ipeds_view ALTER instnm SET COMPRESSION 'DICTIONARY';
ALTER TABLE ipeds_view ALTER typeinst SET COMPRESSION 'DICTIONARY';
ALTER TABLE ipeds_view ALTER insttype SET COMPRESSION 'DICTIONARY';

-- Optimize opt-out data
CREATE TABLE optout_view AS 
SELECT *,
    LOWER(TRIM(Emails)) AS email_normalized
FROM ${OPTOUT_TABLE};

ALTER TABLE optout_view ALTER Source SET COMPRESSION 'DICTIONARY';

-- Then create the comprehensive table
CREATE TABLE comprehensive_data AS
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
ANALYZE comprehensive_data;
