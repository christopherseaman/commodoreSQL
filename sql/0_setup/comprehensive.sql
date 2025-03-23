-- Build comprehensive database
-- Merge survey data with IPEDS and opt-out data
-- Create date field in YYYY-N format
-- Using CTEs for better readability and performance

-- Drop existing objects
DROP VIEW IF EXISTS comprehensive_data;
DROP VIEW IF EXISTS recent_data;
DROP TABLE IF EXISTS invalid_periods;

-- Create a log of records with invalid period formats
CREATE TABLE invalid_periods AS
SELECT "E-Mail", "Instructor", "School", "Period"
FROM survey_data
WHERE "Period" IS NOT NULL 
AND NOT (
    ("Period" LIKE 'Winter %' OR "Period" LIKE 'Spring %' OR 
     "Period" LIKE 'Summer %' OR "Period" LIKE 'Fall %')
    AND 
    LENGTH(TRIM(substr("Period", -4))) = 4 
    AND 
    TRY_CAST(substr("Period", -4) AS INTEGER) BETWEEN 1900 AND 2100
);

-- Create the comprehensive view
CREATE VIEW comprehensive_data AS
WITH survey_with_period AS (
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
    WHERE "Period" IS NOT NULL  -- Early filtering
)
SELECT 
    s.*,
    i.instnm,
    i.sector,
    i.iclevel,
    i.control,
    i.instsize,
    i.efydetot_tot_22,
    i.efyde_tot_22,
    i.typeinst,
    i.insttype,
    CASE WHEN o.Emails IS NOT NULL THEN 1 ELSE 0 END AS is_opted_out,
    o.Source AS opt_out_source
FROM survey_with_period s
LEFT JOIN ipeds_data i ON s."IPED ID" = i.unitid
LEFT JOIN optout_data o ON LOWER(TRIM(s."E-Mail")) = LOWER(TRIM(o.Emails));

-- Create view for recent data (last 2 years)
CREATE VIEW recent_data AS
WITH recent_periods AS (
    SELECT DISTINCT period_sortable 
    FROM comprehensive_data 
    WHERE period_sortable IS NOT NULL 
    ORDER BY period_sortable DESC 
    LIMIT 8
)
SELECT 
    substr(c.period_sortable, 1, 4) as year,
    c.* 
FROM comprehensive_data c
JOIN recent_periods r ON c.period_sortable = r.period_sortable
WHERE c."E-Mail" IS NOT NULL
  AND c.is_opted_out = 0;
