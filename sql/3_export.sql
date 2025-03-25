-- Step 3: Export to CSV
-- This script exports all tables to CSV files

-- Export sample records for inspection (10,000 random records)
COPY (
    SELECT *
    FROM comprehensive_data
    ORDER BY RANDOM()
    LIMIT 10000
) TO '${OUTPUT_DIR}/sample_records.csv' (HEADER, DELIMITER ',');

-- Export mailing lists
COPY (
    SELECT * FROM master_mailing
) TO '${OUTPUT_DIR}/master_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM recent_mailing
) TO '${OUTPUT_DIR}/recent_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM california_mailing
) TO '${OUTPUT_DIR}/california_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM texas_mailing
) TO '${OUTPUT_DIR}/texas_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM florida_mailing
) TO '${OUTPUT_DIR}/florida_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM newyork_mailing
) TO '${OUTPUT_DIR}/newyork_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM texas_fall_series
) TO '${OUTPUT_DIR}/texas_fall_series.csv' (HEADER, DELIMITER ',');

-- Export merged records
COPY (
    SELECT * FROM faculty_records
) TO '${OUTPUT_DIR}/faculty_records.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM course_section_records
) TO '${OUTPUT_DIR}/course_section_records.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM course_records
) TO '${OUTPUT_DIR}/course_records.csv' (HEADER, DELIMITER ','); 