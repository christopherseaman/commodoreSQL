-- Create faculty records
-- Group by email or name within institution
-- Create indicators for record counts by date
-- Using CTEs for better readability and performance

DROP TABLE IF EXISTS faculty_records;
CREATE TABLE faculty_records AS
WITH faculty_minimal AS (
    -- Step 1: Create minimal working set with only needed columns
    SELECT DISTINCT
        "Instructor",
        "School",
        "E-Mail",
        "Department",
        "State",
        "Course Number",
        "Section",
        "Course Title",
        period_sortable,
        -- Create faculty_id consistently
        CASE 
            WHEN "E-Mail" IS NOT NULL AND "E-Mail" != '' 
            THEN "E-Mail" 
            ELSE CONCAT("Instructor", '_', "School") 
        END AS faculty_id
    FROM comprehensive_data
    WHERE 
        "Instructor" IS NOT NULL AND
        "Course Number" IS NOT NULL AND
        "Section" IS NOT NULL AND
        "Course Title" IS NOT NULL
),
faculty_base AS (
    -- Step 2: Create faculty identifiers with basic info
    SELECT DISTINCT
        faculty_id,
        "Instructor",
        "School",
        "E-Mail",
        "Department",
        "State"
    FROM faculty_minimal
),
faculty_period_counts AS (
    -- Step 3: Create period counts using minimal dataset
    SELECT 
        faculty_id,
        period_sortable,
        COUNT(*) AS records_in_period,
        COUNT(DISTINCT CONCAT(
            CAST("Course Number" AS VARCHAR), '_',
            CAST("Section" AS VARCHAR), '_',
            CAST("Course Title" AS VARCHAR)
        )) AS unique_sections_in_period
    FROM faculty_minimal
    GROUP BY faculty_id, period_sortable
),
faculty_latest_period AS (
    -- Step 4: Get most recent period for each faculty
    SELECT DISTINCT
        faculty_id,
        FIRST_VALUE(period_sortable) OVER (
            PARTITION BY faculty_id 
            ORDER BY period_sortable DESC
        ) as latest_period
    FROM faculty_period_counts
)
-- Step 5: Create final faculty records with period counts
SELECT 
    f.faculty_id,
    f."Instructor",
    f."School",
    f."E-Mail",
    f."Department",
    f."State",
    LIST(CONCAT(pc.period_sortable, ':', pc.records_in_period)) AS record_counts_by_period,
    LIST(CONCAT(pc.period_sortable, ':', pc.unique_sections_in_period)) AS section_counts_by_period
FROM faculty_base f
JOIN faculty_latest_period lp ON f.faculty_id = lp.faculty_id
LEFT JOIN faculty_period_counts pc ON f.faculty_id = pc.faculty_id
GROUP BY 
    f.faculty_id,
    f."Instructor",
    f."School",
    f."E-Mail",
    f."Department",
    f."State";

-- Generate data quality report
CREATE TABLE IF NOT EXISTS faculty_records_stats AS
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT faculty_id) as unique_faculty,
    COUNT(*) FILTER (WHERE "E-Mail" IS NOT NULL) as records_with_email,
    COUNT(*) FILTER (WHERE "Department" IS NOT NULL) as records_with_department,
    COUNT(*) FILTER (WHERE "State" IS NOT NULL) as records_with_state,
    COUNT(DISTINCT "School") as unique_schools,
    COUNT(DISTINCT "State") as unique_states
FROM faculty_records;

-- Output statistics
SELECT * FROM faculty_records_stats;
