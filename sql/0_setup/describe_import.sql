-- Describe imported tables to validate their structure
-- This helps ensure the data was imported correctly

-- List all tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'main' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Show row counts for imported data
SELECT 'survey_data' AS table_name, COUNT(*) AS row_count FROM survey_data
UNION ALL
SELECT 'ipeds_data' AS table_name, COUNT(*) AS row_count FROM ipeds_data
UNION ALL
SELECT 'optout_data' AS table_name, COUNT(*) AS row_count FROM optout_data;

-- Describe survey_data table structure
DESCRIBE SELECT * FROM survey_data;

-- Describe ipeds_data table structure
DESCRIBE SELECT * FROM ipeds_data;

-- Describe optout_data table structure
DESCRIBE SELECT * FROM optout_data;

-- Sample data from each table
SELECT * FROM survey_data LIMIT 5;
SELECT * FROM ipeds_data LIMIT 5;
SELECT * FROM optout_data LIMIT 5;
