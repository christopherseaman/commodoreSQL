-- Create course records
-- Combine all sections of a course into a single record
-- Calculate total enrollment and add publisher fields
-- Using CTEs for better readability and performance

DROP TABLE IF EXISTS course_records;
CREATE TABLE course_records AS
WITH course_base AS (
    -- Step 1: Create base course data with aggregated metrics
    SELECT 
        "School",
        "Course Number",
        period_sortable,
        COUNT(DISTINCT section_id) AS num_sections,
        SUM(enrollment) AS total_enrollment,
        COUNT(*) AS records_merged
    FROM course_section_records
    WHERE 
        "School" IS NOT NULL AND
        "Course Number" IS NOT NULL AND
        period_sortable IS NOT NULL
    GROUP BY 
        "School",
        "Course Number",
        period_sortable
    HAVING COUNT(*) > 0  -- Ensure records_merged is positive
),
publisher_data AS (
    -- Intermediate step: Unnest publisher columns
    SELECT 
        "School",
        "Course Number",
        period_sortable,
        UNNEST(ARRAY[publisher_1, publisher_2, publisher_3, publisher_4, publisher_5, publisher_6]) AS p
    FROM course_section_records
    WHERE 
        publisher_1 IS NOT NULL OR
        publisher_2 IS NOT NULL OR
        publisher_3 IS NOT NULL OR
        publisher_4 IS NOT NULL OR
        publisher_5 IS NOT NULL OR
        publisher_6 IS NOT NULL
),
course_publishers AS (
    -- Step 2: Collect publishers for each course
    SELECT 
        "School",
        "Course Number",
        period_sortable,
        ARRAY_AGG(DISTINCT p ORDER BY p) FILTER (WHERE p IS NOT NULL) AS publishers
    FROM publisher_data
    GROUP BY 
        "School",
        "Course Number",
        period_sortable
)
-- Step 3: Create final course records
SELECT 
    CONCAT(
        CAST(b."School" AS VARCHAR), '_',
        CAST(b."Course Number" AS VARCHAR), '_',
        CAST(b.period_sortable AS VARCHAR)
    ) AS course_id,
    b."School",
    b."Course Number",
    b.period_sortable,
    b.num_sections,
    b.total_enrollment,
    b.records_merged,
    -- Extract up to 6 unique publishers
    CASE WHEN ARRAY_LENGTH(p.publishers) >= 1 THEN p.publishers[1] END AS publisher_1,
    CASE WHEN ARRAY_LENGTH(p.publishers) >= 2 THEN p.publishers[2] END AS publisher_2,
    CASE WHEN ARRAY_LENGTH(p.publishers) >= 3 THEN p.publishers[3] END AS publisher_3,
    CASE WHEN ARRAY_LENGTH(publishers) >= 4 THEN p.publishers[4] END AS publisher_4,
    CASE WHEN ARRAY_LENGTH(publishers) >= 5 THEN p.publishers[5] END AS publisher_5,
    CASE WHEN ARRAY_LENGTH(publishers) >= 6 THEN p.publishers[6] END AS publisher_6
FROM course_base b
LEFT JOIN course_publishers p ON 
    b."School" = p."School" AND
    b."Course Number" = p."Course Number" AND
    b.period_sortable = p.period_sortable
WHERE 
    b.num_sections > 0 AND  -- Ensure num_sections is positive
    b.total_enrollment >= 0;  -- Ensure total_enrollment is non-negative

-- Generate data quality report
CREATE TABLE IF NOT EXISTS course_records_stats AS
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT course_id) as unique_courses,
    COUNT(DISTINCT "School") as unique_schools,
    COUNT(DISTINCT "Course Number") as unique_course_numbers,
    COUNT(DISTINCT period_sortable) as unique_periods,
    AVG(num_sections) as avg_sections_per_course,
    MAX(num_sections) as max_sections_per_course,
    AVG(total_enrollment) as avg_total_enrollment,
    MAX(total_enrollment) as max_total_enrollment,
    AVG(records_merged) as avg_records_merged,
    COUNT(*) FILTER (WHERE publisher_1 IS NOT NULL) as records_with_publisher,
    COUNT(*) FILTER (WHERE publisher_2 IS NOT NULL) as records_with_multiple_publishers,
    COUNT(DISTINCT publisher_1) + 
    COUNT(DISTINCT publisher_2) + 
    COUNT(DISTINCT publisher_3) + 
    COUNT(DISTINCT publisher_4) + 
    COUNT(DISTINCT publisher_5) + 
    COUNT(DISTINCT publisher_6) as total_unique_publishers
FROM course_records;

-- Output statistics
SELECT * FROM course_records_stats;
