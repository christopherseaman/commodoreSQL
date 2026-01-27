-- Import bookprices sample data for OER identification and pricing analysis
-- This script imports sample pricing data from institutional bookstores and publishers

BEGIN TRANSACTION;

-- Drop existing bookprices tables
DROP TABLE IF EXISTS bookprices_institutional;
DROP TABLE IF EXISTS bookprices_publisher;

-- Convert Excel files to CSV if not already done
-- Note: This should be run via a pre-processing step
-- xlsx2csv.py is used externally to convert Excel to CSV

-- Import institutional bookstore pricing data (Barnes & Noble sample)
CREATE TABLE bookprices_institutional AS
SELECT
    TRY_CAST(iped_id AS INTEGER) AS unit_id,
    TRIM(Name) AS institution_name,
    TRIM(address) AS bookstore_url,
    TRIM(Engine) AS pricing_engine,
    TRY_CAST("Book Pricing Date" AS DATE) AS pricing_date,
    TRIM("Term Name") AS term_name,
    TRY_CAST(Year AS INTEGER) AS year,
    TRY_CAST(Term AS INTEGER) AS term,
    TRY_CAST(BatchId AS INTEGER) AS batch_id,
    TRIM("Department Code") AS dept_code,
    TRIM("Department Name") AS dept_name,
    TRIM(Course) AS course,
    TRIM(Section) AS section,
    TRIM(Crn) AS crn,
    LOWER(TRIM("Book Status")) AS book_status,
    LOWER(TRIM("Book Option")) AS book_option, -- buy, rental, access code
    LOWER(TRIM("Book Condition")) AS book_condition, -- new, used
    LOWER(TRIM("Book Format")) AS book_format, -- physical, digital
    TRY_CAST(Price AS DECIMAL(10,2)) AS price,
    TRY_CAST("Rental Length (Days)" AS INTEGER) AS rental_days,
    TRY_CAST("Return Date" AS DATE) AS return_date,
    TRIM(CAST(ISBN13 AS VARCHAR)) AS isbn13,
    TRIM(Title) AS title,
    TRIM(Author) AS author,
    TRIM(Publisher) AS publisher,
    TRIM(Edition) AS edition,
    -- Derive course_id for joining with main catalog
    TRIM(Name) || '::' || COALESCE(NULLIF(TRIM("Department Name"), ''), 'UNKNOWN') || '::' || COALESCE(NULLIF(TRIM(Course), ''), 'UNKNOWN') AS course_id
FROM read_csv('/tmp/bookpricing_sample.csv',
    header = true,
    delim = ',',
    quote = '"',
    escape = '"',
    nullstr = 'NULL',
    auto_detect = true
);

-- Import publisher list pricing data (Cengage sample)
CREATE TABLE bookprices_publisher AS
SELECT
    TRY_CAST(Date AS TIMESTAMP) AS pricing_date,
    TRIM(CAST(ISBN13 AS VARCHAR)) AS isbn13,
    TRIM(Title) AS title,
    TRIM(Author) AS author,
    TRIM(Publisher) AS publisher,
    TRY_CAST(PublishDate AS DATE) AS publish_date,
    TRY_CAST(Year AS INTEGER) AS year,
    TRIM(Edition) AS edition,
    LOWER(TRIM(BookType)) AS book_type, -- eTextbook, Hardcopy, Bundle
    LOWER(TRIM(PurchaseType)) AS purchase_type, -- Buy, Rental, Subscription
    TRY_CAST(Price AS DECIMAL(10,2)) AS price,
    TRIM(RentalLength) AS rental_length,
    TRIM(FormatDescription) AS format_description,
    LOWER(TRIM(lifecycleStatus)) AS lifecycle_status -- unlimited, active, etc.
FROM read_csv('/tmp/publisher_pricing_sample.csv',
    header = true,
    delim = ',',
    quote = '"',
    escape = '"',
    auto_detect = true
);

-- Create summary view of unique publishers from bookprices data
CREATE OR REPLACE VIEW bookprices_publishers AS
SELECT DISTINCT
    publisher,
    COUNT(*) as occurrence_count,
    CASE
        WHEN LOWER(publisher) LIKE '%openstax%' THEN true
        WHEN LOWER(publisher) LIKE '%oer%' THEN true
        WHEN publisher = 'OER' THEN true
        ELSE false
    END AS is_likely_oer
FROM (
    SELECT publisher FROM bookprices_institutional WHERE publisher IS NOT NULL
    UNION ALL
    SELECT publisher FROM bookprices_publisher WHERE publisher IS NOT NULL
) combined
GROUP BY publisher
ORDER BY occurrence_count DESC;

COMMIT;

-- Summary statistics
SELECT 'Institutional bookstore records' AS metric, COUNT(*)::VARCHAR AS count FROM bookprices_institutional
UNION ALL
SELECT 'Publisher pricing records', COUNT(*)::VARCHAR FROM bookprices_publisher
UNION ALL
SELECT 'Unique ISBNs (institutional)', COUNT(DISTINCT isbn13)::VARCHAR FROM bookprices_institutional WHERE isbn13 IS NOT NULL
UNION ALL
SELECT 'Unique ISBNs (publisher)', COUNT(DISTINCT isbn13)::VARCHAR FROM bookprices_publisher WHERE isbn13 IS NOT NULL
UNION ALL
SELECT 'Unique publishers (institutional)', COUNT(DISTINCT publisher)::VARCHAR FROM bookprices_institutional WHERE publisher IS NOT NULL
UNION ALL
SELECT 'Unique publishers (list)', COUNT(DISTINCT publisher)::VARCHAR FROM bookprices_publisher WHERE publisher IS NOT NULL
UNION ALL
SELECT 'Likely OER publishers', COUNT(*)::VARCHAR FROM bookprices_publishers WHERE is_likely_oer = true;
