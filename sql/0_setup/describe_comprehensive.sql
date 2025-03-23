-- Describe comprehensive database tables to validate their structure
-- This helps ensure the joins and transformations were done correctly

-- List all tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'main' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Show row counts for main tables
SELECT 'survey_data' AS table_name, COUNT(*) AS row_count FROM survey_data
UNION ALL
SELECT 'ipeds_data' AS table_name, COUNT(*) AS row_count FROM ipeds_data
UNION ALL
SELECT 'optout_data' AS table_name, COUNT(*) AS row_count FROM optout_data
UNION ALL
SELECT 'comprehensive_data' AS table_name, COUNT(*) AS row_count FROM comprehensive_data;

-- Describe main tables structure
DESCRIBE SELECT * FROM survey_data;
DESCRIBE SELECT * FROM ipeds_data;
DESCRIBE SELECT * FROM optout_data;
DESCRIBE SELECT * FROM comprehensive_data;

-- Inspect actual period data
SELECT DISTINCT "Period" FROM survey_data ORDER BY "Period";
SELECT "Period", LENGTH("Period") as length, substr("Period", -4) as year_part 
FROM survey_data 
WHERE "Period" IS NOT NULL 
LIMIT 10;

-- Verify period_sortable field
SELECT "Period", period_sortable, COUNT(*) 
FROM comprehensive_data 
GROUP BY "Period", period_sortable 
ORDER BY period_sortable 
LIMIT 10;

-- Verify IPEDS join
SELECT COUNT(*) AS matched_ipeds_count, 
       COUNT(*) * 100.0 / (SELECT COUNT(*) FROM survey_data) AS match_percentage
FROM comprehensive_data
WHERE instnm IS NOT NULL;

-- Inspect IPEDS join failures
SELECT DISTINCT s."IPED ID", i.unitid, s."School", i.instnm
FROM survey_data s
LEFT JOIN ipeds_data i ON s."IPED ID" = i.unitid
WHERE s."IPED ID" IS NOT NULL AND i.unitid IS NULL
LIMIT 10;

-- Verify opt-out join
SELECT 
    CASE WHEN is_opted_out = 1 THEN 'Opted Out' ELSE 'Not Opted Out' END AS opt_out_status,
    COUNT(*) AS record_count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM comprehensive_data) AS percentage
FROM comprehensive_data 
GROUP BY is_opted_out;

-- Inspect opt-out join failures
SELECT DISTINCT s."E-Mail", o.Emails
FROM survey_data s
LEFT JOIN optout_data o ON LOWER(TRIM(s."E-Mail")) = LOWER(TRIM(o.Emails))
WHERE s."E-Mail" IS NOT NULL AND o.Emails IS NOT NULL
LIMIT 10;

-- Sample data from comprehensive view
SELECT * FROM comprehensive_data LIMIT 5;
