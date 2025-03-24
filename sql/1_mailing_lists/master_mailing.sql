-- Create master mailing list
-- This script creates the main mailing list by:
-- 1. Filtering out opted-out records and invalid emails
-- 2. Deduplicating records by email using priority rules:
--    - Most recent period first
--    - Largest enrollment next
--    - Random selection for ties
--
-- Input:
-- - comprehensive_data: Main view containing all survey data
--
-- Output:
-- - master_mailing: Table containing deduplicated mailing list
-- - idx_master_mailing_email: Index on email for faster lookups
--
-- Example output row:
-- {
--   "E-Mail": "instructor@university.edu",
--   "Instructor": "John Smith",
--   "School": "University Name",
--   "Period": "Fall 2023",
--   "Enrollments": 150,
--   ... (other fields from comprehensive_data)
-- }

-- Use CTEs for better readability and performance
DROP TABLE IF EXISTS master_mailing;
CREATE TABLE master_mailing AS
WITH email_keys AS (
    -- Step 1: Create minimal dataset for deduplication
    -- We only need these fields to determine which record to keep
    SELECT 
        "E-Mail",
        period_sortable,  -- For sorting by recency
        "Enrollments",    -- For sorting by size
        RANDOM() as random_key  -- For breaking ties
    FROM comprehensive_data
    WHERE 
        "E-Mail" IS NOT NULL AND 
        "E-Mail" != '' AND
        is_opted_out = 0
),
ranked_emails AS (
    -- Step 2: Rank emails by priority rules
    -- For each email address, rank the records based on:
    -- 1. Most recent period (DESC)
    -- 2. Largest enrollment (DESC)
    -- 3. Random selection for ties
    SELECT 
        "E-Mail",
        ROW_NUMBER() OVER (
            PARTITION BY "E-Mail" 
            ORDER BY 
                period_sortable DESC,  -- Most recent date first
                "Enrollments" DESC,    -- Largest enrollment next
                random_key            -- Random selection for ties
        ) AS rank
    FROM email_keys
),
winning_emails AS (
    -- Step 3: Get winning email records
    -- Only keep the highest ranked record for each email
    SELECT "E-Mail"
    FROM ranked_emails
    WHERE rank = 1
)
-- Step 4: Create final master mailing list
-- Join back with comprehensive_data to get all fields
SELECT c.*
FROM comprehensive_data c
JOIN winning_emails w ON c."E-Mail" = w."E-Mail"
WHERE c.is_opted_out = 0;

-- Create index on email for potential future use
-- This will speed up any queries that filter or join on email
CREATE INDEX IF NOT EXISTS idx_master_mailing_email ON master_mailing("E-Mail");
