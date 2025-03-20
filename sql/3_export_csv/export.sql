-- Export tables to CSV files
-- This file uses variables that will be substituted by the shell script

-- Export sample records for inspection (10,000 random records)
COPY (
    SELECT *
    FROM comprehensive_data
    ORDER BY RANDOM()
    LIMIT 10000
) TO '${OUTPUT_DIR}/sample_records.csv' (HEADER, DELIMITER ',');

-- Export master mailing list
COPY (
    SELECT *
    FROM master_mailing
) TO '${OUTPUT_DIR}/master_mailing.csv' (HEADER, DELIMITER ',');

-- Export recent mailing list (last 2 years)
COPY (
    SELECT *
    FROM recent_mailing
) TO '${OUTPUT_DIR}/recent_mailing.csv' (HEADER, DELIMITER ',');

-- Export state-specific mailing lists
COPY (
    SELECT *
    FROM california_mailing
) TO '${OUTPUT_DIR}/california_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT *
    FROM texas_mailing
) TO '${OUTPUT_DIR}/texas_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT *
    FROM florida_mailing
) TO '${OUTPUT_DIR}/florida_mailing.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT *
    FROM newyork_mailing
) TO '${OUTPUT_DIR}/newyork_mailing.csv' (HEADER, DELIMITER ',');

-- Export Texas time series
COPY (
    SELECT *
    FROM texas_fall_series
) TO '${OUTPUT_DIR}/texas_fall_series.csv' (HEADER, DELIMITER ',');

-- Export faculty records
COPY (
    SELECT *
    FROM faculty_records
) TO '${OUTPUT_DIR}/faculty_records.csv' (HEADER, DELIMITER ',');

-- Export course section records
COPY (
    SELECT *
    FROM course_section_records
) TO '${OUTPUT_DIR}/course_section_records.csv' (HEADER, DELIMITER ',');

-- Export course records
COPY (
    SELECT *
    FROM course_records
) TO '${OUTPUT_DIR}/course_records.csv' (HEADER, DELIMITER ',');
