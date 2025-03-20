-- Create course records
-- Combine all sections of a course into a single record
-- Calculate total enrollment and add publisher fields

CREATE TABLE IF NOT EXISTS course_records AS
WITH course_groups AS (
    SELECT 
        CONCAT("Institution", '_', "Course Number", '_', period_sortable) AS course_id,
        "Institution",
        "Course Number",
        period_sortable,
        COUNT(DISTINCT section_id) AS num_sections,
        SUM(enrollment) AS total_enrollment,
        COUNT(*) AS records_merged,
        -- Collect all publishers across sections
        ARRAY_AGG(DISTINCT publisher_1) FILTER (WHERE publisher_1 IS NOT NULL) ||
        ARRAY_AGG(DISTINCT publisher_2) FILTER (WHERE publisher_2 IS NOT NULL) ||
        ARRAY_AGG(DISTINCT publisher_3) FILTER (WHERE publisher_3 IS NOT NULL) ||
        ARRAY_AGG(DISTINCT publisher_4) FILTER (WHERE publisher_4 IS NOT NULL) ||
        ARRAY_AGG(DISTINCT publisher_5) FILTER (WHERE publisher_5 IS NOT NULL) ||
        ARRAY_AGG(DISTINCT publisher_6) FILTER (WHERE publisher_6 IS NOT NULL) AS all_publishers
    FROM course_section_records
    GROUP BY 
        "Institution",
        "Course Number",
        period_sortable
)
SELECT 
    course_id,
    "Institution",
    "Course Number",
    period_sortable,
    num_sections,
    total_enrollment,
    records_merged,
    -- Extract up to 6 unique publishers
    all_publishers[1] AS publisher_1,
    all_publishers[2] AS publisher_2,
    all_publishers[3] AS publisher_3,
    all_publishers[4] AS publisher_4,
    all_publishers[5] AS publisher_5,
    all_publishers[6] AS publisher_6
FROM course_groups;
