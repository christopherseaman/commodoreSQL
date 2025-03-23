-- Create course section records
-- Group by course number, section, title within institution and date
-- Add publisher fields
-- Using CTEs for better readability and performance

DROP TABLE IF EXISTS course_section_records;
CREATE TABLE course_section_records AS
WITH section_base AS (
    -- Step 1: Create base section data with only needed columns
    SELECT DISTINCT
        "School",
        "Course Number",
        "Section",
        "Course Title",
        period_sortable,
        "Publisher",
        "Enrollments"
    FROM comprehensive_data
    WHERE 
        "Course Number" IS NOT NULL AND 
        "Section" IS NOT NULL AND
        "Course Title" IS NOT NULL AND
        period_sortable IS NOT NULL AND
        "Enrollments" >= 0
),
section_groups AS (
    -- Step 2: Create section groups with aggregated data
    SELECT 
        CONCAT(
            CAST("School" AS VARCHAR), '_',
            CAST("Course Number" AS VARCHAR), '_',
            CAST("Section" AS VARCHAR), '_',
            CAST("Course Title" AS VARCHAR), '_',
            CAST(period_sortable AS VARCHAR)
        ) AS section_id,
        "School",
        "Course Number",
        "Section",
        "Course Title",
        period_sortable,
        MAX("Enrollments") AS enrollment,
        COUNT(*) AS records_merged,
        -- Extract publishers (up to 6) with explicit ordering for consistency
        ARRAY_AGG(DISTINCT "Publisher" ORDER BY "Publisher") FILTER (WHERE "Publisher" IS NOT NULL AND "Publisher" != '') AS publishers
    FROM section_base
    GROUP BY 
        "School",
        "Course Number",
        "Section",
        "Course Title",
        period_sortable
    HAVING COUNT(*) > 0  -- Ensure records_merged is positive
)
-- Step 3: Create final course section records
SELECT 
    section_id,
    "School",
    "Course Number",
    "Section",
    "Course Title",
    period_sortable,
    enrollment,
    records_merged,
    -- Extract up to 6 publishers
    CASE WHEN ARRAY_LENGTH(publishers) >= 1 THEN publishers[1] END AS publisher_1,
    CASE WHEN ARRAY_LENGTH(publishers) >= 2 THEN publishers[2] END AS publisher_2,
    CASE WHEN ARRAY_LENGTH(publishers) >= 3 THEN publishers[3] END AS publisher_3,
    CASE WHEN ARRAY_LENGTH(publishers) >= 4 THEN publishers[4] END AS publisher_4,
    CASE WHEN ARRAY_LENGTH(publishers) >= 5 THEN publishers[5] END AS publisher_5,
    CASE WHEN ARRAY_LENGTH(publishers) >= 6 THEN publishers[6] END AS publisher_6
FROM section_groups;

-- Generate data quality report
CREATE TABLE IF NOT EXISTS course_section_records_stats AS
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT section_id) as unique_sections,
    COUNT(DISTINCT "School") as unique_schools,
    COUNT(DISTINCT "Course Number") as unique_courses,
    COUNT(DISTINCT period_sortable) as unique_periods,
    AVG(enrollment) as avg_enrollment,
    MAX(enrollment) as max_enrollment,
    AVG(records_merged) as avg_records_merged,
    COUNT(*) FILTER (WHERE publisher_1 IS NOT NULL) as records_with_publisher,
    COUNT(*) FILTER (WHERE publisher_2 IS NOT NULL) as records_with_multiple_publishers,
    COUNT(DISTINCT publisher_1) + 
    COUNT(DISTINCT publisher_2) + 
    COUNT(DISTINCT publisher_3) + 
    COUNT(DISTINCT publisher_4) + 
    COUNT(DISTINCT publisher_5) + 
    COUNT(DISTINCT publisher_6) as total_unique_publishers
FROM course_section_records;

-- Output statistics
SELECT * FROM course_section_records_stats;
