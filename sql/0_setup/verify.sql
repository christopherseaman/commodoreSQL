-- Verify tables exist and show row counts
-- This is a simple verification that tables were created and have data

-- List all tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'main' AND (table_type = 'BASE TABLE' OR table_type = 'VIEW')
ORDER BY table_name;

-- Show row counts for key tables
SELECT 'survey_data' AS table_name, COUNT(*) AS row_count FROM survey_data
UNION ALL
SELECT 'ipeds_data' AS table_name, COUNT(*) AS row_count FROM ipeds_data
UNION ALL
SELECT 'optout_data' AS table_name, COUNT(*) AS row_count FROM optout_data;

-- Check for additional tables if they exist
SELECT 
    table_name, 
    'Available' AS status
FROM 
    information_schema.tables 
WHERE 
    table_schema = 'main' 
    AND table_name IN ('survey_data_prepared', 'survey_with_ipeds', 'comprehensive_data');
