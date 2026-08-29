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
DROP TABLE IF EXISTS panel_email;
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
    LOWER(TRIM("Book Status")) AS book_status,
    "IPED ID" AS unit_id,
    "School" AS school,
    -- "SchoolYearType" AS school_year_type,  -- Excluded: not needed for current analysis
    "State" AS state,
    "Dept Code" AS dept_code,
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
    COALESCE(CAST("IPED ID" AS VARCHAR), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Dept Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Course Number"), ''), 'UNKNOWN') AS course_id,
    -- section_id includes period to keep grain unique across semesters (the same section
    -- number recurs each term with different instructors). period_sortable is computed inline
    -- here so the column itself can also be exposed below.
    COALESCE(CAST("IPED ID" AS VARCHAR), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Dept Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Course Number"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Section"), ''), 'UNKNOWN') || '::' ||
    COALESCE(
        CASE
            WHEN "Period" LIKE 'Winter %' THEN substr("Period", -4) || '-1'
            WHEN "Period" LIKE 'Spring %' THEN substr("Period", -4) || '-2'
            WHEN "Period" LIKE 'Summer %' THEN substr("Period", -4) || '-3'
            WHEN "Period" LIKE 'Fall %' THEN substr("Period", -4) || '-4'
        END,
        'UNKNOWN'
    ) AS section_id,
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
-- Note: sector/iclevel/control/instsize are STRING descriptors in the source CSV
-- (e.g., 'Public, 4-year or above', 'Four or more years', '20,000 and above'),
-- not numeric codes — keep as VARCHAR.
CREATE TABLE ${IPEDS_TABLE} AS
SELECT
    TRY_CAST("UNITID" AS INTEGER) AS unitid,
    "INSTNM" AS instnm,
    "SECTOR"   AS sector,
    "ICLEVEL"  AS iclevel,
    "CONTROL"  AS control,
    "INSTSIZE" AS instsize,
    TRY_CAST("Enroll_24" AS INTEGER) AS enroll_24,
    TRY_CAST("DistEnroll_24" AS INTEGER) AS dist_enroll_24,
    "InstType" AS inst_type
FROM read_csv('${IPEDS_CSV}',
    compression='auto',
    header=true,
    delim=',',
    nullstr=['N/A', '', 'Not applicable', '{Not available}', 'Sector unknown (not active)']);

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

-- Preserve the mailing-history source at source-row grain, and expose a
-- one-row-per-email lookup for catalog enrichment. Joining the raw history
-- directly can multiply catalog rows when an email has responses in multiple
-- years.
CREATE TABLE panel_email AS
SELECT
    email,
    MAX(response_year) AS panel_response_year,
    COUNT(*) AS panel_source_row_count,
    COUNT(DISTINCT response_year) AS panel_response_year_variant_count
FROM ${PANEL_TABLE}
GROUP BY email;

-- Export email cleaning audit to TSV (import artifact, not a persistent table)
COPY (
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
    FROM raw_emails
) TO '${OUTPUT_DIR}/email_issues.tsv' (DELIMITER '\t', HEADER);

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
    p.panel_response_year,
    p.panel_source_row_count,
    p.panel_response_year_variant_count
FROM ${SURVEY_TABLE} c
LEFT JOIN ${IPEDS_TABLE} i ON c.unit_id = i.unitid
LEFT JOIN ${OPTOUT_TABLE} o ON c.email = o.email
LEFT JOIN panel_email p ON c.email = p.email;

COMMIT;

-- Update query optimization statistics
ANALYZE ${SURVEY_TABLE};
ANALYZE ${IPEDS_TABLE};
ANALYZE ${OPTOUT_TABLE};
ANALYZE ${PANEL_TABLE};
ANALYZE panel_email;
ANALYZE comprehensive_data;

-- =====================================================================
-- Data Quality checks (console-only — see TODO.md for persistent logging)
-- =====================================================================

-- DQ: lookup multiplicity must remain visible in the raw history while the
-- catalog enrichment stays exactly one row per normalized catalog source row.
SELECT
    'Panel lookup multiplicity' AS metric,
    (SELECT COUNT(*) FROM ${PANEL_TABLE}) AS panel_source_rows,
    (SELECT COUNT(*) FROM panel_email) AS panel_distinct_emails,
    (SELECT COUNT(*) FROM ${PANEL_TABLE})
      - (SELECT COUNT(*) FROM panel_email) AS panel_duplicate_email_rows,
    (SELECT COUNT(*) FROM panel_email WHERE panel_source_row_count > 1)
        AS panel_emails_with_multiple_rows,
    (SELECT COUNT(*) FROM panel_email WHERE panel_response_year_variant_count > 1)
        AS panel_emails_with_multiple_years;

SELECT
    'Provisional catalog enrichment one-to-one' AS metric,
    (SELECT COUNT(*) FROM ${SURVEY_TABLE}) AS catalog_source_rows,
    (SELECT COUNT(*) FROM comprehensive_data) AS enriched_rows,
    (SELECT COUNT(*) FROM comprehensive_data)
      - (SELECT COUNT(*) FROM ${SURVEY_TABLE}) AS row_difference;

-- DQ: 'UNKNOWN' segments in composite IDs (silent missing-source-data signal)
SELECT
    'Catalog composite-key UNKNOWN segments' AS metric,
    COUNT(*) FILTER (WHERE section_id LIKE '%UNKNOWN%') AS section_id_unknown_rows,
    COUNT(*) FILTER (WHERE course_id  LIKE '%UNKNOWN%') AS course_id_unknown_rows,
    COUNT(*) FILTER (WHERE period_sortable IS NULL)     AS null_period_sortable_rows
FROM comprehensive_data;

-- DQ: IPEDS match — split unmatched into Canadian (no unit_id) vs closed/consolidated US schools
-- Background: IPEDS_2024.csv covers US institutions only. ~70% of unmatched is by design (CA schools);
-- the remainder is ~80 distinct unit_ids for closed/merged/consolidated US institutions.
SELECT
    'Catalog → IPEDS match' AS metric,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE c.unit_id IS NULL)                          AS no_unit_id_likely_canadian,
    COUNT(*) FILTER (WHERE c.unit_id IS NOT NULL AND i.unitid IS NULL) AS unit_id_not_in_ipeds,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i.unitid IS NULL) / COUNT(*), 2) AS pct_unmatched_total
FROM ${SURVEY_TABLE} c
LEFT JOIN ${IPEDS_TABLE} i ON c.unit_id = i.unitid;

-- DQ: schools missing from IPEDS_2024.csv (top 10 by row count)
SELECT
    'Top schools missing IPEDS' AS check_name,
    c.school,
    c.unit_id,
    COUNT(*) AS catalog_rows
FROM ${SURVEY_TABLE} c
LEFT JOIN ${IPEDS_TABLE} i ON c.unit_id = i.unitid
WHERE i.unitid IS NULL
GROUP BY c.school, c.unit_id
ORDER BY catalog_rows DESC
LIMIT 10;

-- DQ: NULL ISBN13 distribution by school (top 10 sources)
SELECT
    'Top schools by NULL ISBN13' AS check_name,
    school,
    COUNT(*) AS null_isbn_rows,
    COUNT(DISTINCT section_id) AS distinct_sections
FROM ${SURVEY_TABLE}
WHERE ISBN13 IS NULL
GROUP BY school
ORDER BY null_isbn_rows DESC
LIMIT 10;

-- DQ: email validity (loose) — what survived cleaning that still looks bad
SELECT
    'Email loose-validity check' AS metric,
    COUNT(*) FILTER (WHERE email IS NULL) AS email_null,
    COUNT(*) FILTER (WHERE email IS NOT NULL AND email NOT LIKE '%@%') AS email_no_at,
    COUNT(*) FILTER (WHERE email IS NOT NULL AND email LIKE '%@%' AND email NOT LIKE '%.%') AS email_no_dot,
    COUNT(*) FILTER (WHERE email IS NOT NULL AND LENGTH(email) < 5) AS email_too_short
FROM ${SURVEY_TABLE};

-- DQ: enrollment sanity — split into sentinel (9999 = uncapped/unspecified) vs real overages.
-- Source uses seats_taken=9999 for research / topics-vary courses without enrollment limits.
SELECT
    'Enrollment sanity' AS metric,
    COUNT(*) FILTER (WHERE enrollments < 0)                                   AS enrollments_negative,
    COUNT(*) FILTER (WHERE seats_taken < 0)                                   AS seats_taken_negative,
    COUNT(*) FILTER (WHERE seats_taken = 9999)                                AS seats_taken_sentinel_9999,
    COUNT(*) FILTER (WHERE seats_taken > enrollments AND seats_taken < 9999
                       AND seats_taken - enrollments BETWEEN 1 AND 5)         AS overage_small_1_to_5,
    COUNT(*) FILTER (WHERE seats_taken > enrollments AND seats_taken < 9999
                       AND seats_taken - enrollments BETWEEN 6 AND 100)       AS overage_medium_6_to_100,
    COUNT(*) FILTER (WHERE seats_taken > enrollments AND seats_taken < 9999
                       AND seats_taken - enrollments > 100)                   AS overage_large_over_100,
    COUNT(*) FILTER (WHERE enrollments > 10000)                               AS enrollments_implausibly_large
FROM ${SURVEY_TABLE};
