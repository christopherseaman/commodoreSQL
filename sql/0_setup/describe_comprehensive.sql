-- Describe comprehensive database tables to validate their structure
-- This helps ensure the joins and transformations were done correctly

-- List all tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'main' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Show row counts for comprehensive database tables
SELECT 'survey_data_prepared' AS table_name, COUNT(*) AS row_count FROM survey_data_prepared
UNION ALL
SELECT 'survey_with_ipeds' AS table_name, COUNT(*) AS row_count FROM survey_with_ipeds
UNION ALL
SELECT 'comprehensive_data' AS table_name, COUNT(*) AS row_count FROM comprehensive_data;

-- Describe survey_data_prepared table structure
DESCRIBE SELECT * FROM survey_data_prepared;

-- Describe survey_with_ipeds table structure
DESCRIBE SELECT * FROM survey_with_ipeds;

-- Describe comprehensive_data table structure
DESCRIBE SELECT * FROM comprehensive_data;

-- Verify period_sortable field
SELECT period, period_sortable, COUNT(*) 
FROM survey_data_prepared 
GROUP BY period, period_sortable 
ORDER BY period_sortable 
LIMIT 10;

-- Verify IPEDS join
SELECT COUNT(*) AS matched_ipeds_count, COUNT(*) * 100.0 / (SELECT COUNT(*) FROM survey_data_prepared) AS match_percentage
FROM survey_with_ipeds
WHERE instnm IS NOT NULL;

-- Verify opt-out join
SELECT 
    CASE WHEN is_opted_out = 1 THEN 'Opted Out' ELSE 'Not Opted Out' END AS opt_out_status,
    COUNT(*) AS record_count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM comprehensive_data) AS percentage
FROM comprehensive_data 
GROUP BY is_opted_out;

-- Sample data from each table
SELECT * FROM survey_data_prepared LIMIT 5;
SELECT * FROM survey_with_ipeds LIMIT 5;
SELECT * FROM comprehensive_data LIMIT 5;
