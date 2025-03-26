-- Configure DuckDB for export
SET threads=1;
SET memory_limit='2GB';
SET temp_directory='./tmp';

-- Create a temporary view for the export
CREATE OR REPLACE TEMP VIEW export_view AS
SELECT
    -- Primary contact information
    "E-Mail",
    "Instructor",
    "FirstName",
    "LastName",
    
    -- Institution information
    "School",
    "Department",
    "State"
FROM master_mailing;

-- Export to CSV using native COPY command
COPY export_view TO 'output/test_master_mailing.csv' (
    HEADER,
    DELIMITER ','
); 