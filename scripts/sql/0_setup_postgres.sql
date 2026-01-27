-- Prepare and merge data sources for comprehensive analysis
BEGIN;

-- Clear existing data structures
DROP TABLE IF EXISTS ${SURVEY_TABLE} CASCADE;
DROP TABLE IF EXISTS ${IPEDS_TABLE} CASCADE;
DROP TABLE IF EXISTS ${OPTOUT_TABLE} CASCADE;
DROP TABLE IF EXISTS ${MERGED_TABLE} CASCADE;

-- Create IPEDS data table (smaller file)
CREATE TABLE ${IPEDS_TABLE} (
    unitid TEXT,
    instnm TEXT,
    sector TEXT,
    iclevel TEXT,
    control TEXT,
    instsize TEXT,
    efydetot_tot_22 TEXT,
    efyde_tot_22 TEXT,
    typeinst TEXT,
    insttype TEXT
);

-- Load IPEDS data
COPY ${IPEDS_TABLE} FROM '/import/${IPEDS_CSV}' WITH (FORMAT CSV, HEADER);

-- No type conversion needed for IPEDS data as all columns contain text values

-- Create opt-out data table (smaller file)
CREATE TABLE ${OPTOUT_TABLE} (
    "Emails " TEXT,
    Source TEXT
);

-- Load opt-out data
COPY ${OPTOUT_TABLE} FROM '/import/${OPTOUT_CSV}' WITH (FORMAT CSV, HEADER);

-- Normalize opt-out data
ALTER TABLE ${OPTOUT_TABLE} 
    ADD COLUMN email_normalized TEXT;

UPDATE ${OPTOUT_TABLE} 
SET email_normalized = LOWER(TRIM("Emails "));

-- Create survey data table (larger file)
CREATE TABLE ${SURVEY_TABLE} (
    ISBN13 TEXT,
    Title TEXT,
    Author TEXT,
    Publisher TEXT,
    Imprint TEXT,
    Edition TEXT,
    "Published Year" INTEGER,
    Format TEXT,
    FormatType TEXT,
    "IPED ID" INTEGER,
    School TEXT,
    SchoolYearType TEXT,
    State TEXT,
    "Dept Code" TEXT,
    Department TEXT,
    "Dept Description" TEXT,
    "Course Number" TEXT,
    Section TEXT,
    "Course Title" TEXT,
    "Course Level" TEXT,
    "Course Subject" TEXT,
    Period TEXT,
    Enrollments TEXT,  -- Load as TEXT first to handle N/A values
    Instructor TEXT,
    FirstName TEXT,
    LastName TEXT,
    "E-Mail" TEXT,
    "Seats Taken" INTEGER,
    "Book Status" TEXT
);

-- Load survey data
COPY ${SURVEY_TABLE} FROM '/import/${SURVEY_CSV}' WITH (FORMAT CSV, HEADER);

-- Normalize survey data
ALTER TABLE ${SURVEY_TABLE} 
    ALTER COLUMN "E-Mail" TYPE TEXT USING LOWER(TRIM("E-Mail")),
    ADD COLUMN period_sortable TEXT,
    ALTER COLUMN Enrollments TYPE INTEGER USING 
        CASE 
            WHEN Enrollments = 'N/A' THEN NULL 
            ELSE Enrollments::INTEGER 
        END;

UPDATE ${SURVEY_TABLE} 
SET period_sortable = CASE
    WHEN Period LIKE 'Winter %' THEN substr(Period, -4) || '-1'
    WHEN Period LIKE 'Spring %' THEN substr(Period, -4) || '-2'
    WHEN Period LIKE 'Summer %' THEN substr(Period, -4) || '-3'
    WHEN Period LIKE 'Fall %' THEN substr(Period, -4) || '-4'
    ELSE NULL
END;

-- Index survey data for performance
CREATE INDEX idx_survey_email ON ${SURVEY_TABLE} ("E-Mail");
CREATE INDEX idx_survey_ipedid ON ${SURVEY_TABLE} ("IPED ID");
CREATE INDEX idx_survey_state ON ${SURVEY_TABLE} (State);
CREATE INDEX idx_survey_period ON ${SURVEY_TABLE} (period_sortable);
CREATE INDEX idx_survey_course ON ${SURVEY_TABLE} ("Course Number", Section, "Course Title");

-- Create comprehensive merged dataset
CREATE TABLE ${MERGED_TABLE} AS
WITH survey_with_period AS (
    -- Standardize period representation
    SELECT *,
        CASE
            WHEN Period LIKE 'Winter %' AND LENGTH(TRIM(substr(Period, -4))) = 4 
                THEN substr(Period, -4) || '-1'
            WHEN Period LIKE 'Spring %' AND LENGTH(TRIM(substr(Period, -4))) = 4 
                THEN substr(Period, -4) || '-2'
            WHEN Period LIKE 'Summer %' AND LENGTH(TRIM(substr(Period, -4))) = 4 
                THEN substr(Period, -4) || '-3'
            WHEN Period LIKE 'Fall %' AND LENGTH(TRIM(substr(Period, -4))) = 4 
                THEN substr(Period, -4) || '-4'
            ELSE NULL
        END AS period_sortable
    FROM ${SURVEY_TABLE}
    WHERE Period IS NOT NULL
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
    CASE WHEN o."Emails " IS NOT NULL THEN 1 ELSE 0 END AS is_opted_out,
    o.Source AS opt_out_source
FROM survey_with_period s
LEFT JOIN ${IPEDS_TABLE} i ON s."IPED ID" = i.unitid
LEFT JOIN ${OPTOUT_TABLE} o ON LOWER(TRIM(s."E-Mail")) = LOWER(TRIM(o."Emails "));

-- Create indexes for performance
CREATE INDEX idx_merged_ipeds_id ON ${MERGED_TABLE}("IPED ID");
CREATE INDEX idx_merged_email ON ${MERGED_TABLE}("E-Mail");

COMMIT; 