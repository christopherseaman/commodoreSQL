-- Import historical bookstore pricing data and derive section_id for catalog joins.
-- Stages: raw → dedupe byte-identical → dedupe all-but-instructor → keep most-recent snapshot → pricing_historical
--   1. Byte-identical duplicate rows (vendor export emits same row twice).
--   2. Rows that differ ONLY by instructor name (co-taught sections listed once per instructor).
--   3. Same logical key emitted at multiple pricing_date snapshots — vendor re-exports the same
--      adoption multiple times. Keep the most-recent snapshot per key (collapses ~1.45M dup-key
--      groups into one row each).
-- After all three dedupe stages, pricing_historical is at its natural unique grain.

${CONFIG}

BEGIN TRANSACTION;

-- Clear existing pricing tables
DROP TABLE IF EXISTS pricing_historical;
-- Legacy pre-period section-status artifact; no current pipeline stage consumes it.
DROP TABLE IF EXISTS pricing_section_status;
DROP TABLE IF EXISTS pricing_raw;
DROP TABLE IF EXISTS pricing_dedup_full;
DROP TABLE IF EXISTS bookprices_institutional;
DROP TABLE IF EXISTS bookprices_publisher;
DROP VIEW IF EXISTS bookprices_publishers;

-- Stage 1: raw load with derived columns
CREATE TEMP TABLE pricing_raw AS
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
    (LOWER(TRIM("Book Status")) = 'required') AS required,
    LOWER(TRIM("Book Option")) AS book_option,
    LOWER(TRIM("Book Condition")) AS book_condition,
    LOWER(TRIM("Book Format")) AS book_format,
    TRY_CAST(Price AS DECIMAL(10,2)) AS price,
    TRY_CAST("Rental Length" AS INTEGER) AS rental_days,
    TRY_CAST("Return Date" AS DATE) AS return_date,
    -- Derive IDs matching catalog logic (0_setup.sql)
    COALESCE(CAST(IPEDSID AS VARCHAR), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Department Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Course Code"), ''), 'UNKNOWN') AS course_id,
    COALESCE(CAST(IPEDSID AS VARCHAR), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Department Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Course Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(NULLIF(TRIM("Section Code"), ''), 'UNKNOWN') || '::' ||
    COALESCE(
        CASE
            WHEN Period LIKE 'Winter %' THEN substr(Period, -4) || '-1'
            WHEN Period LIKE 'Spring %' THEN substr(Period, -4) || '-2'
            WHEN Period LIKE 'Summer %' THEN substr(Period, -4) || '-3'
            WHEN Period LIKE 'Fall %' THEN substr(Period, -4) || '-4'
        END,
        'UNKNOWN'
    ) AS section_id,
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

-- Stage 2: byte-identical dedupe (vendor export sometimes emits the same row twice)
CREATE TEMP TABLE pricing_dedup_full AS
SELECT DISTINCT * FROM pricing_raw;

-- Stage 3: dedupe all-but-instructor (co-taught sections list one row per instructor).
-- Aggregate instructors via STRING_AGG so multi-instructor info is preserved as comma-separated.
DROP TABLE IF EXISTS pricing_dedup_instructor;
CREATE TEMP TABLE pricing_dedup_instructor AS
SELECT
    unit_id, institute, bookstore_url, pricing_date, period,
    dept_code, dept_name, course_code, section_code, crn,
    STRING_AGG(DISTINCT instructor_name, ', ' ORDER BY instructor_name) AS instructor_name,
    isbn13, title, author, publisher, edition,
    book_status, required, book_option, book_condition, book_format,
    price, rental_days, return_date,
    course_id, section_id, period_sortable, period_date
FROM pricing_dedup_full
GROUP BY
    unit_id, institute, bookstore_url, pricing_date, period,
    dept_code, dept_name, course_code, section_code, crn,
    isbn13, title, author, publisher, edition,
    book_status, required, book_option, book_condition, book_format,
    price, rental_days, return_date,
    course_id, section_id, period_sortable, period_date;

-- Stage 4: keep the most-recent snapshot per logical key.
-- Vendor re-exports the same adoption at multiple pricing_dates; we keep the latest record.
-- Tie-break (same date, e.g., metadata refinement) is arbitrary via ROW_NUMBER.
CREATE TABLE pricing_historical AS
SELECT * EXCLUDE (_snapshot_rank)
FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY section_id, isbn13, book_option, book_condition, book_format, rental_days
            ORDER BY pricing_date DESC NULLS LAST
        ) AS _snapshot_rank
    FROM pricing_dedup_instructor
)
WHERE _snapshot_rank = 1;

-- pricing_historical is source-owned and receives no downstream catalog updates.
-- Build its indexes after the final table write so DuckDB ART '=' lookups remain
-- correct (#49). DROP+CREATE keeps this stage independently re-runnable.
DROP INDEX IF EXISTS idx_pricing_section;
DROP INDEX IF EXISTS idx_pricing_isbn;
DROP INDEX IF EXISTS idx_pricing_period;
CREATE INDEX idx_pricing_section ON pricing_historical (section_id);
CREATE INDEX idx_pricing_isbn    ON pricing_historical (isbn13);
CREATE INDEX idx_pricing_period  ON pricing_historical (period_sortable);

COMMIT;

-- DQ: dedupe stage counts
SELECT
    'Pricing dedupe stages' AS metric,
    (SELECT COUNT(*) FROM pricing_raw)               AS raw_csv_rows,
    (SELECT COUNT(*) FROM pricing_raw)               - (SELECT COUNT(*) FROM pricing_dedup_full)        AS removed_byte_identical,
    (SELECT COUNT(*) FROM pricing_dedup_full)        - (SELECT COUNT(*) FROM pricing_dedup_instructor)  AS collapsed_multi_instructor,
    (SELECT COUNT(*) FROM pricing_dedup_instructor)  - (SELECT COUNT(*) FROM pricing_historical)        AS collapsed_old_snapshots,
    (SELECT COUNT(*) FROM pricing_historical)        AS final_rows;

-- Cleanup temp tables
DROP TABLE IF EXISTS pricing_raw;
DROP TABLE IF EXISTS pricing_dedup_full;
DROP TABLE IF EXISTS pricing_dedup_instructor;

-- Summary statistics
SELECT 'Pricing historical records' AS metric, COUNT(*)::VARCHAR AS value FROM pricing_historical
UNION ALL
SELECT 'Unique section_ids', COUNT(DISTINCT section_id)::VARCHAR FROM pricing_historical
UNION ALL
SELECT 'Unique ISBNs', COUNT(DISTINCT isbn13)::VARCHAR FROM pricing_historical WHERE isbn13 IS NOT NULL
UNION ALL
SELECT 'Period range', MIN(period) || ' - ' || MAX(period) FROM pricing_historical;

-- Granularity check (post-dedupe): expect 0 unexplained_residual.
-- Anything > 0 here would indicate a bug in the dedupe stages or new source noise pattern.
SELECT
    'Pricing residual grain check (post-dedupe)' AS metric,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (section_id, isbn13, book_option, book_condition, book_format, rental_days)) AS unique_keys,
    COUNT(*) - COUNT(DISTINCT (section_id, isbn13, book_option, book_condition, book_format, rental_days)) AS unexplained_residual
FROM pricing_historical;

-- DQ: price outliers — bookstores often use 0 as placeholder; > $1000 is unusual
SELECT
    'Pricing price outliers' AS metric,
    COUNT(*) FILTER (WHERE price IS NULL)        AS price_null,
    COUNT(*) FILTER (WHERE price = 0)            AS price_zero,
    COUNT(*) FILTER (WHERE price > 0 AND price < 1) AS price_under_1,
    COUNT(*) FILTER (WHERE price > 1000)         AS price_over_1000
FROM pricing_historical;

-- DQ: buy/rental field discipline — buys should not have rental_days, rentals should
SELECT
    'Pricing buy/rental discipline' AS metric,
    COUNT(*) FILTER (WHERE book_option IS NULL AND price IS NOT NULL)          AS option_null_with_price,
    COUNT(*) FILTER (WHERE book_option = 'buy'    AND rental_days IS NOT NULL) AS buy_with_rental_days,
    COUNT(*) FILTER (WHERE book_option = 'rental' AND rental_days IS NULL)     AS rental_without_rental_days_total,
    COUNT(*) FILTER (WHERE book_option = 'rental' AND rental_days = 0)         AS rental_days_zero,
    COUNT(*) FILTER (WHERE book_option = 'rental' AND rental_days > 1825)      AS rental_days_over_5yr
FROM pricing_historical;

-- DQ: rental_days consistency within (section, isbn) digital rentals
-- Investigation (2026-05-05/06) confirmed:
--   physical rentals always have NULL rental_days (semester-implicit "for the semester") — expected
--   digital rentals usually have rental_days set (subscription term) — expected
--   NULL rental_days is only a real issue when MIXED null/non-null within the same (section, isbn)
--   digital rental group (~1.3K pairs = 0.04% of digital rental pairs).
WITH digital_per_pair AS (
    SELECT section_id, isbn13,
        COUNT(*) FILTER (WHERE rental_days IS NULL)     AS digital_null,
        COUNT(*) FILTER (WHERE rental_days IS NOT NULL) AS digital_set
    FROM pricing_historical
    WHERE book_option = 'rental' AND book_format = 'digital'
    GROUP BY section_id, isbn13
)
SELECT
    'Pricing rental_days consistency (digital)' AS metric,
    COUNT(*) AS pairs_with_digital_rental,
    COUNT(*) FILTER (WHERE digital_null > 0 AND digital_set = 0) AS all_null_consistent,
    COUNT(*) FILTER (WHERE digital_null = 0 AND digital_set > 0) AS all_set_consistent,
    COUNT(*) FILTER (WHERE digital_null > 0 AND digital_set > 0) AS mixed_real_dq_issue
FROM digital_per_pair;

-- DQ: 'UNKNOWN' segments in pricing section_id — these are by-construction when source cells
-- are missing; surfaced as a count signal (not a defect indicator).
SELECT
    'Pricing section_id UNKNOWN segments' AS metric,
    COUNT(*) FILTER (WHERE section_id LIKE '%UNKNOWN%') AS rows_with_unknown_segment,
    COUNT(DISTINCT section_id) FILTER (WHERE section_id LIKE '%UNKNOWN%') AS distinct_section_ids_affected
FROM pricing_historical;
