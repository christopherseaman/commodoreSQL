-- Prepare and merge data sources for comprehensive analysis

${CONFIG}

BEGIN TRANSACTION;

-- Clear existing data structures
DROP TABLE IF EXISTS comprehensive_data;
DROP TABLE IF EXISTS survey_data;
DROP TABLE IF EXISTS ipeds_view;
DROP TABLE IF EXISTS optout_view;
DROP TABLE IF EXISTS panel_view;
DROP TABLE IF EXISTS ${SURVEY_TABLE};
DROP TABLE IF EXISTS ${IPEDS_TABLE};
DROP TABLE IF EXISTS ${OPTOUT_TABLE};
DROP TABLE IF EXISTS ${PANEL_TABLE};
DROP TABLE IF EXISTS email_issues;

-- Import and normalize course catalog data
CREATE TABLE ${SURVEY_TABLE} AS
SELECT
    "ISBN13",
    "Title",
    "Author",
    "Publisher",
    "Imprint",
    -- "Edition" AS edition,  -- Excluded: not needed for current analysis
    -- "Published Year" AS published_year,  -- Excluded: not needed for current analysis
    "Format",
    "FormatType",
    "Book Status" AS book_status,
    "IPED ID" AS unit_id,
    "School" AS school,
    -- "SchoolYearType" AS school_year_type,  -- Excluded: not needed for current analysis
    "State" AS state,
    -- "Dept Code" AS dept_code,  -- Excluded: have dept_description instead
    "Department" AS department,
    "Dept Description" AS dept_description,
    "Course Number" AS course_number,
    "Section" AS section,
    "Course Title" AS course_title,
    "Course Level" AS course_level,
    "Course Subject" AS course_subject,
    "Period" AS period,
    TRY_CAST("Enrollments" AS INTEGER) AS enrollments,
    TRY_CAST("Seats Taken" AS INTEGER) AS seats_taken,
    "Instructor" AS instructor,
    "FirstName" AS first_name,
    "LastName" AS last_name,
    -- Clean and normalize email addresses
    LOWER(TRIM(
        CASE
            -- Extract email from "email: addr@domain.com" patterns
            WHEN "E-Mail" LIKE '%email:%@%' THEN REGEXP_EXTRACT("E-Mail", '([a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', 1)
            -- Extract email from "email addr@domain.com" patterns
            WHEN "E-Mail" LIKE '%email %@%' THEN REGEXP_EXTRACT("E-Mail", '([a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', 1)
            -- Extract first email if multiple emails present
            WHEN "E-Mail" LIKE '%@% %@%' THEN SPLIT_PART("E-Mail", ' ', 1)
            -- Remove interior spaces from otherwise valid emails
            WHEN "E-Mail" LIKE '% %' AND "E-Mail" LIKE '%@%' THEN REPLACE("E-Mail", ' ', '')
            -- Already clean
            ELSE "E-Mail"
        END
    )) AS email,
    -- Derived fields: Use :: as delimiter (pipe | appears in source data)
    -- NULLIF treats empty strings as NULL, then COALESCE provides default
    COALESCE(NULLIF(TRIM("School"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Department"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Course Number"), ''), 'UNKNOWN') AS course_id,
    COALESCE(NULLIF(TRIM("School"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Department"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Course Number"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Section"), ''), 'UNKNOWN') AS section_id,
    CASE
        WHEN "Period" LIKE 'Winter %' THEN substr("Period", -4) || '-1'
        WHEN "Period" LIKE 'Spring %' THEN substr("Period", -4) || '-2'
        WHEN "Period" LIKE 'Summer %' THEN substr("Period", -4) || '-3'
        WHEN "Period" LIKE 'Fall %' THEN substr("Period", -4) || '-4'
        ELSE NULL
    END AS period_sortable,
    CASE
        WHEN "Period" LIKE 'Winter %' THEN CAST(substr("Period", -4) || '-01-01' AS DATE)
        WHEN "Period" LIKE 'Spring %' THEN CAST(substr("Period", -4) || '-04-01' AS DATE)
        WHEN "Period" LIKE 'Summer %' THEN CAST(substr("Period", -4) || '-07-01' AS DATE)
        WHEN "Period" LIKE 'Fall %' THEN CAST(substr("Period", -4) || '-10-01' AS DATE)
        ELSE NULL
    END AS period_date,
FROM read_csv('${SURVEY_CSV}',
    compression='auto',
    header=true,
    delim=',',
    quote='"',
    escape='"',
    nullstr=['N/A', '', 'Not applicable']);

-- Index course catalog data for performance
CREATE INDEX idx_course_email ON ${SURVEY_TABLE} (email);
CREATE INDEX idx_course_unitid ON ${SURVEY_TABLE} (unit_id);
CREATE INDEX idx_course_period ON ${SURVEY_TABLE} (period_sortable);
CREATE INDEX idx_course_courseid ON ${SURVEY_TABLE} (course_id);
CREATE INDEX idx_course_sectionid ON ${SURVEY_TABLE} (section_id);

-- Import IPEDS institutional data
CREATE TABLE ${IPEDS_TABLE} AS
SELECT
    TRY_CAST("UNITID" AS INTEGER) AS unitid,
    "INSTNM" AS instnm,
    TRY_CAST("SECTOR" AS INTEGER) AS sector,
    TRY_CAST("ICLEVEL" AS INTEGER) AS iclevel,
    TRY_CAST("CONTROL" AS INTEGER) AS control,
    TRY_CAST("INSTSIZE" AS INTEGER) AS instsize,
    TRY_CAST("Enroll_24" AS INTEGER) AS enroll_24,
    TRY_CAST("DistEnroll_24" AS INTEGER) AS dist_enroll_24,
    "InstType" AS inst_type
FROM read_csv('${IPEDS_CSV}',
    compression='auto',
    header=true,
    delim=',',
    nullstr=['N/A', '', 'Not applicable']);

-- Import and normalize opt-out data
CREATE TABLE ${OPTOUT_TABLE} AS
SELECT
    LOWER(TRIM("Email")) AS email,
    "Source" AS source
FROM read_csv('${OPTOUT_CSV}',
    compression='auto',
    header=true,
    delim=',',
    nullstr=['N/A', '', 'Not applicable']);

-- Import panel response data
CREATE TABLE ${PANEL_TABLE} AS
SELECT
    LOWER(TRIM("Unique")) AS email,
    "Year" AS response_year
FROM read_csv('${PANEL_CSV}',
    compression='auto',
    header=true,
    delim=',',
    nullstr=['N/A', '', 'Not applicable']);

-- Create email quality check table showing raw vs cleaned emails
CREATE TABLE email_issues AS
WITH raw_emails AS (
    SELECT DISTINCT
        "E-Mail" AS email_raw,
        'course_catalog' AS source_table
    FROM read_csv('${SURVEY_CSV}',
        compression='auto',
        header=true,
        delim=',',
        quote='"',
        escape='"',
        nullstr=['N/A', '', 'Not applicable'])
    WHERE "E-Mail" LIKE '% %'
       OR "E-Mail" LIKE '%email:%'
       OR "E-Mail" LIKE '%email %'
       OR "E-Mail" LIKE '%@% %@%'
       OR ("E-Mail" IS NOT NULL AND "E-Mail" != '' AND "E-Mail" NOT LIKE '%@%')
       OR LENGTH(TRIM("E-Mail")) < 5
)
SELECT
    email_raw,
    LOWER(TRIM(
        CASE
            WHEN email_raw LIKE '%email:%@%' THEN REGEXP_EXTRACT(email_raw, '([a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', 1)
            WHEN email_raw LIKE '%email %@%' THEN REGEXP_EXTRACT(email_raw, '([a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', 1)
            WHEN email_raw LIKE '%@% %@%' THEN SPLIT_PART(email_raw, ' ', 1)
            WHEN email_raw LIKE '% %' AND email_raw LIKE '%@%' THEN REPLACE(email_raw, ' ', '')
            ELSE email_raw
        END
    )) AS email_cleaned,
    source_table,
    CASE
        WHEN email_raw LIKE '%email:%@%' OR email_raw LIKE '%email %@%' THEN 'extracted_from_text'
        WHEN email_raw LIKE '%@% %@%' THEN 'multiple_emails_took_first'
        WHEN email_raw LIKE '% %' AND email_raw LIKE '%@%' THEN 'removed_spaces'
        WHEN email_raw NOT LIKE '%@%' THEN 'missing_at_sign'
        WHEN LENGTH(TRIM(email_raw)) < 5 THEN 'too_short'
        ELSE 'other'
    END AS cleaning_action
FROM raw_emails;

-- Create comprehensive merged dataset
CREATE TABLE comprehensive_data AS
SELECT
    c.*,
    i.instnm,
    i.sector,
    i.iclevel,
    i.control,
    i.instsize,
    i.enroll_24,
    i.dist_enroll_24,
    i.inst_type,
    CASE WHEN o.email IS NOT NULL THEN 1 ELSE 0 END AS is_opted_out,
    o.source AS opt_out_source,
    p.response_year AS panel_response_year
FROM ${SURVEY_TABLE} c
LEFT JOIN ${IPEDS_TABLE} i ON c.unit_id = i.unitid
LEFT JOIN ${OPTOUT_TABLE} o ON c.email = o.email
LEFT JOIN ${PANEL_TABLE} p ON c.email = p.email;

COMMIT;

-- Update query optimization statistics
ANALYZE ${SURVEY_TABLE};
ANALYZE ${IPEDS_TABLE};
ANALYZE ${OPTOUT_TABLE};
ANALYZE ${PANEL_TABLE};
ANALYZE email_issues;
ANALYZE comprehensive_data;
