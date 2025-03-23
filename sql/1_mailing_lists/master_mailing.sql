-- Create master mailing list
-- Filter out opt-out records and records with no email
-- Deduplicate by email using priority rules

-- Use CTEs for better readability and performance
DROP TABLE IF EXISTS master_mailing;
CREATE TABLE master_mailing AS
WITH email_keys AS (
    -- Step 1: Create minimal dataset for deduplication
    SELECT 
        "E-Mail",
        period_sortable,
        "Enrollments",
        RANDOM() as random_key
    FROM comprehensive_data
    WHERE 
        "E-Mail" IS NOT NULL AND 
        "E-Mail" != '' AND
        is_opted_out = 0
),
ranked_emails AS (
    -- Step 2: Rank emails by priority rules
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
    SELECT "E-Mail"
    FROM ranked_emails
    WHERE rank = 1
)
-- Step 4: Create final master mailing list
SELECT c.*
FROM comprehensive_data c
JOIN winning_emails w ON c."E-Mail" = w."E-Mail"
WHERE c.is_opted_out = 0;

-- Create index on email for potential future use
CREATE INDEX IF NOT EXISTS idx_master_mailing_email ON master_mailing("E-Mail");
