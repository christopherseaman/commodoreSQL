-- Prepare and merge data sources for comprehensive analysis

${CONFIG}

BEGIN TRANSACTION;

-- Clear existing data structures
DROP TABLE IF EXISTS comprehensive_data;
DROP TABLE IF EXISTS survey_data;
DROP TABLE IF EXISTS ipeds_view;
DROP TABLE IF EXISTS optout_view;
DROP TABLE IF EXISTS ${SURVEY_TABLE};
DROP TABLE IF EXISTS ${IPEDS_TABLE};
DROP TABLE IF EXISTS ${OPTOUT_TABLE};

-- Import and normalize survey data
CREATE TABLE ${SURVEY_TABLE} AS
SELECT 
    *,
    LOWER(TRIM("E-Mail")) AS "E-Mail",
    CASE
        WHEN "Period" LIKE 'Winter %' THEN substr("Period", -4) || '-1'
        WHEN "Period" LIKE 'Spring %' THEN substr("Period", -4) || '-2'
        WHEN "Period" LIKE 'Summer %' THEN substr("Period", -4) || '-3'
        WHEN "Period" LIKE 'Fall %' THEN substr("Period", -4) || '-4'
        ELSE NULL
    END AS period_sortable
FROM read_csv('${SURVEY_CSV}',
    compression='auto',
    header=true,
    delim=',',
    quote='"',
    escape='"',
    nullstr=['N/A', '', 'Not applicable']);

-- Convert survey enrollments to integer
ALTER TABLE ${SURVEY_TABLE} ALTER "Enrollments" TYPE INTEGER USING TRY_CAST("Enrollments" AS INTEGER);

-- Index survey data for performance
CREATE INDEX idx_survey_email ON ${SURVEY_TABLE} ("E-Mail");
CREATE INDEX idx_survey_ipedid ON ${SURVEY_TABLE} ("IPED ID");
CREATE INDEX idx_survey_state ON ${SURVEY_TABLE} ("State");
CREATE INDEX idx_survey_period ON ${SURVEY_TABLE} (period_sortable);
CREATE INDEX idx_survey_course ON ${SURVEY_TABLE} ("Course Number", "Section", "Course Title");

-- Import IPEDS institutional data
CREATE TABLE ${IPEDS_TABLE} AS
SELECT * FROM read_csv('${IPEDS_CSV}', 
    compression='auto',
    header=true, 
    delim=',', 
    nullstr=['N/A', '', 'Not applicable']);

-- Normalize IPEDS data types
ALTER TABLE ${IPEDS_TABLE} ALTER sector TYPE INTEGER USING TRY_CAST(sector AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER iclevel TYPE INTEGER USING TRY_CAST(iclevel AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER control TYPE INTEGER USING TRY_CAST(control AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER instsize TYPE INTEGER USING TRY_CAST(instsize AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER efydetot_tot_22 TYPE INTEGER USING TRY_CAST(efydetot_tot_22 AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER efyde_tot_22 TYPE INTEGER USING TRY_CAST(efyde_tot_22 AS INTEGER);

-- Import and normalize opt-out data
CREATE TABLE ${OPTOUT_TABLE} AS
SELECT 
    *,
    LOWER(TRIM("Emails")) AS email_normalized
FROM read_csv('${OPTOUT_CSV}', 
    compression='auto',
    header=true, 
    delim=',', 
    nullstr=['N/A', '', 'Not applicable']);

-- Prepare views for data integration
CREATE TABLE ipeds_view AS 
SELECT 
    *,
    CAST(unitid AS VARCHAR) AS unitid_str
FROM ${IPEDS_TABLE};

CREATE TABLE optout_view AS 
SELECT *
FROM ${OPTOUT_TABLE};

-- Create comprehensive merged dataset
CREATE TABLE comprehensive_data AS
WITH survey_with_period AS (
    -- Standardize period representation
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
    FROM ${SURVEY_TABLE}
    WHERE "Period" IS NOT NULL
)
SELECT 
    s.*,  -- Survey data
    i.instnm,      -- Institution name
    i.sector,      -- Institution sector
    i.iclevel,     -- Institution level
    i.control,     -- Control type
    i.instsize,    -- Institution size
    i.efydetot_tot_22,  -- Total enrollment
    i.efyde_tot_22,     -- Degree-seeking enrollment
    i.typeinst,    -- Institution type
    i.insttype,    -- Detailed institution type
    CASE WHEN o.Emails IS NOT NULL THEN 1 ELSE 0 END AS is_opted_out,
    o.Source AS opt_out_source
FROM survey_with_period s
LEFT JOIN ipeds_view i ON s."IPED ID" = i.unitid
LEFT JOIN optout_view o ON LOWER(TRIM(s."E-Mail")) = LOWER(TRIM(o.Emails));

COMMIT;

-- Update query optimization statistics
ANALYZE ${SURVEY_TABLE};
ANALYZE ${IPEDS_TABLE};
ANALYZE ${OPTOUT_TABLE};
ANALYZE comprehensive_data;
