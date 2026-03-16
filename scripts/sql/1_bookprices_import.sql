-- Import historical bookstore pricing data and derive section_id for catalog joins

${CONFIG}

BEGIN TRANSACTION;

-- Clear existing pricing tables
DROP TABLE IF EXISTS pricing_historical;
DROP TABLE IF EXISTS bookprices_institutional;
DROP TABLE IF EXISTS bookprices_publisher;
DROP VIEW IF EXISTS bookprices_publishers;

-- Import historical bookstore pricing data
CREATE TABLE pricing_historical AS
SELECT
    TRY_CAST(IPEDSID AS INTEGER) AS unit_id,
    TRIM(Institute) AS institute,
    TRIM(Address) AS bookstore_url,
    TRY_CAST("Book Pricing Date" AS TIMESTAMP) AS pricing_date,
    TRIM(Period) AS period,
    TRIM("Department Code") AS dept_code,
    TRIM("Department Name") AS dept_name,
    TRIM("Course Code") AS course_code,
    TRIM("Section Code") AS section_code,
    TRIM(CRN) AS crn,
    TRIM("Instructor Name") AS instructor_name,
    TRIM(ISBN13) AS isbn13,
    TRIM(Title) AS title,
    TRIM(Author) AS author,
    TRIM(Publisher) AS publisher,
    TRIM(Edition) AS edition,
    LOWER(TRIM("Book Status")) AS book_status,
    LOWER(TRIM("Book Option")) AS book_option,
    LOWER(TRIM("Book Condition")) AS book_condition,
    LOWER(TRIM("Book Format")) AS book_format,
    TRY_CAST(Price AS DECIMAL(10,2)) AS price,
    TRY_CAST("Rental Length" AS INTEGER) AS rental_days,  -- VARCHAR from reader, cast to INT
    TRY_CAST("Return Date" AS DATE) AS return_date,
    -- Derive IDs matching catalog logic (0_setup.sql uses "Dept Code")
    COALESCE(CAST(IPEDSID AS VARCHAR), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Department Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Course Code"), ''), 'UNKNOWN') AS course_id,
    COALESCE(CAST(IPEDSID AS VARCHAR), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Department Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Course Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Section Code"), ''), 'UNKNOWN') AS section_id,
    CASE
        WHEN Period LIKE 'Winter %' THEN substr(Period, -4) || '-1'
        WHEN Period LIKE 'Spring %' THEN substr(Period, -4) || '-2'
        WHEN Period LIKE 'Summer %' THEN substr(Period, -4) || '-3'
        WHEN Period LIKE 'Fall %' THEN substr(Period, -4) || '-4'
        ELSE NULL
    END AS period_sortable,
    CASE
        WHEN Period LIKE 'Winter %' THEN CAST(substr(Period, -4) || '-01-01' AS DATE)
        WHEN Period LIKE 'Spring %' THEN CAST(substr(Period, -4) || '-04-01' AS DATE)
        WHEN Period LIKE 'Summer %' THEN CAST(substr(Period, -4) || '-07-01' AS DATE)
        WHEN Period LIKE 'Fall %' THEN CAST(substr(Period, -4) || '-10-01' AS DATE)
        ELSE NULL
    END AS period_date
FROM read_csv('${PRICING_CSV}',
    compression='auto',
    header=true,
    delim=',',
    quote='"',
    escape='"',
    nullstr=['N/A', '', 'Not applicable'],
    types={'CRN': 'VARCHAR', 'ISBN13': 'VARCHAR', 'Edition': 'VARCHAR', 'Rental Length': 'VARCHAR'});

-- Index for joins and lookups
CREATE INDEX idx_pricing_section ON pricing_historical (section_id);
CREATE INDEX idx_pricing_isbn ON pricing_historical (isbn13);
CREATE INDEX idx_pricing_period ON pricing_historical (period_sortable);

COMMIT;

-- Summary statistics
SELECT 'Pricing historical records' AS metric, COUNT(*)::VARCHAR AS value FROM pricing_historical
UNION ALL
SELECT 'Unique section_ids', COUNT(DISTINCT section_id)::VARCHAR FROM pricing_historical
UNION ALL
SELECT 'Unique ISBNs', COUNT(DISTINCT isbn13)::VARCHAR FROM pricing_historical WHERE isbn13 IS NOT NULL
UNION ALL
SELECT 'Period range', MIN(period) || ' - ' || MAX(period) FROM pricing_historical;
