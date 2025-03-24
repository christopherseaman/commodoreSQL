-- Build comprehensive database
-- This script creates the main comprehensive view that combines survey data with IPEDS and opt-out information
-- It performs several key transformations:
-- 1. Standardizes period formats (e.g., "Fall 2023" -> "2023-4")
-- 2. Validates period data and logs invalid entries
-- 3. Joins survey data with institutional (IPEDS) data
-- 4. Adds opt-out status information
--
-- Key tables used:
-- - survey_data: Contains the main survey responses
-- - ipeds_data: Contains institutional information from IPEDS database
-- - optout_data: Contains list of opted-out email addresses
--
-- Output views:
-- - comprehensive_data: Main view combining all data sources
-- - recent_data: Filtered view showing only last 2 years of data
-- - invalid_periods: Log of records with invalid period formats

-- Drop existing objects to ensure clean slate
DROP VIEW IF EXISTS comprehensive_data;
DROP VIEW IF EXISTS recent_data;
DROP TABLE IF EXISTS invalid_periods;

-- Create a log of records with invalid period formats
-- This helps identify data quality issues in the survey responses
CREATE TABLE invalid_periods AS
SELECT "E-Mail", "Instructor", "School", "Period"
FROM survey_data
WHERE "Period" IS NOT NULL 
AND NOT (
    -- Valid period format: [Season] [Year] (e.g., "Fall 2023")
    -- Season must be one of: Winter, Spring, Summer, Fall
    -- Year must be a 4-digit number between 1900 and 2100
    ("Period" LIKE 'Winter %' OR "Period" LIKE 'Spring %' OR 
     "Period" LIKE 'Summer %' OR "Period" LIKE 'Fall %')
    AND 
    LENGTH(TRIM(substr("Period", -4))) = 4 
    AND 
    TRY_CAST(substr("Period", -4) AS INTEGER) BETWEEN 1900 AND 2100
);

-- Create the comprehensive view that combines all data sources
CREATE VIEW comprehensive_data AS
WITH survey_with_period AS (
    -- Step 1: Standardize period format for easier sorting and filtering
    -- Convert "Fall 2023" to "2023-4" format where:
    -- - Winter = 1
    -- - Spring = 2
    -- - Summer = 3
    -- - Fall = 4
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
    WHERE "Period" IS NOT NULL  -- Early filtering for better performance
)
-- Step 2: Join with IPEDS and opt-out data
SELECT 
    s.*,  -- All survey fields
    -- IPEDS institutional information
    i.instnm,      -- Institution name
    i.sector,      -- Institution sector (public/private)
    i.iclevel,     -- Institution level (2-year/4-year)
    i.control,     -- Control type (public/private)
    i.instsize,    -- Institution size category
    i.efydetot_tot_22,  -- Total enrollment
    i.efyde_tot_22,     -- Degree-seeking enrollment
    i.typeinst,    -- Institution type
    i.insttype,    -- Detailed institution type
    -- Opt-out status
    CASE WHEN o.Emails IS NOT NULL THEN 1 ELSE 0 END AS is_opted_out,
    o.Source AS opt_out_source
FROM survey_with_period s
-- Join with IPEDS data using institution ID
LEFT JOIN ipeds_data i ON s."IPED ID" = i.unitid
-- Join with opt-out data using email address (case-insensitive)
LEFT JOIN optout_data o ON LOWER(TRIM(s."E-Mail")) = LOWER(TRIM(o.Emails));

-- Create view for recent data (last 2 years)
-- This view is used for analysis of recent trends
CREATE VIEW recent_data AS
WITH recent_periods AS (
    -- Get the 8 most recent periods (2 years worth)
    SELECT DISTINCT period_sortable 
    FROM comprehensive_data 
    WHERE period_sortable IS NOT NULL 
    ORDER BY period_sortable DESC 
    LIMIT 8
)
SELECT 
    substr(c.period_sortable, 1, 4) as year,  -- Extract year for easier grouping
    c.* 
FROM comprehensive_data c
JOIN recent_periods r ON c.period_sortable = r.period_sortable
-- Only include records with valid email and not opted out
WHERE c."E-Mail" IS NOT NULL
  AND c.is_opted_out = 0;
