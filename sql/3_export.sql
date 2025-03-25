-- Step 3: Export to CSV
-- This script exports all tables to CSV files in batches of 100k records

-- Helper function to export data in batches
CREATE OR REPLACE FUNCTION export_in_batches(
    source_query STRING, 
    output_file STRING, 
    batch_size INTEGER DEFAULT 100000
) AS $$
BEGIN
    -- Create a temporary table to store the row count
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_row_count AS 
    SELECT COUNT(*) AS total_rows FROM (SELECT * FROM (${source_query})) AS src;
    
    -- Get the total number of rows
    DECLARE total_rows INTEGER;
    SELECT total_rows INTO total_rows FROM temp_row_count;
    
    -- Calculate the number of batches
    DECLARE num_batches INTEGER;
    SET num_batches = CEIL(total_rows::FLOAT / batch_size);
    
    -- Export the header only in the first batch
    DECLARE i INTEGER;
    SET i = 0;
    
    WHILE i < num_batches DO
        -- Export the current batch
        IF i = 0 THEN
            -- First batch with header
            COPY (
                SELECT * FROM (${source_query}) AS src
                LIMIT ${batch_size} OFFSET (${i} * ${batch_size})
            ) TO '${output_file}' (HEADER, DELIMITER ',');
        ELSE
            -- Subsequent batches without header, append mode
            COPY (
                SELECT * FROM (${source_query}) AS src
                LIMIT ${batch_size} OFFSET (${i} * ${batch_size})
            ) TO '${output_file}' (HEADER false, DELIMITER ',');
        END IF;
        
        SET i = i + 1;
    END WHILE;
    
    -- Clean up
    DROP TABLE IF EXISTS temp_row_count;
END;
$$;

-- Export sample records for inspection (10,000 random records)
COPY (
    SELECT *
    FROM comprehensive_data
    ORDER BY RANDOM()
    LIMIT 10000
) TO '${OUTPUT_DIR}/sample_records.csv' (HEADER, DELIMITER ',');

-- Export mailing lists in batches of 100k records
CALL export_in_batches(
    'SELECT 
        "E-Mail",
        "Instructor",
        "School",
        "Department",
        "State",
        period_sortable
    FROM master_mailing',
    '${OUTPUT_DIR}/master_mailing.csv'
);

CALL export_in_batches(
    'SELECT * FROM recent_mailing',
    '${OUTPUT_DIR}/recent_mailing.csv'
);

CALL export_in_batches(
    'SELECT * FROM california_mailing',
    '${OUTPUT_DIR}/california_mailing.csv'
);

CALL export_in_batches(
    'SELECT * FROM texas_mailing',
    '${OUTPUT_DIR}/texas_mailing.csv'
);

CALL export_in_batches(
    'SELECT * FROM florida_mailing',
    '${OUTPUT_DIR}/florida_mailing.csv'
);

CALL export_in_batches(
    'SELECT * FROM newyork_mailing',
    '${OUTPUT_DIR}/newyork_mailing.csv'
);

CALL export_in_batches(
    'SELECT * FROM texas_fall_series',
    '${OUTPUT_DIR}/texas_fall_series.csv'
);

-- Export merged records in batches of 100k records
CALL export_in_batches(
    'SELECT * FROM faculty_records',
    '${OUTPUT_DIR}/faculty_records.csv'
);

CALL export_in_batches(
    'SELECT * FROM course_section_records',
    '${OUTPUT_DIR}/course_section_records.csv'
);

CALL export_in_batches(
    'SELECT * FROM course_records',
    '${OUTPUT_DIR}/course_records.csv'
);
