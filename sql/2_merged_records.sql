-- Step 2: Create Merged Records
-- This script creates:
-- 1. Faculty records (grouped by email or name)
-- 2. Course section records
-- 3. Course records

-- Create faculty records
DROP TABLE IF EXISTS faculty_records;
CREATE TABLE faculty_records AS
SELECT 
    -- Use email as primary key, fallback to name+school
    CASE 
        WHEN "E-Mail" IS NOT NULL AND "E-Mail" != '' 
        THEN "E-Mail" 
        ELSE CONCAT("Instructor", '_', "School") 
    END AS faculty_id,
    "Instructor",
    "School",
    "E-Mail",
    "Department",
    "State",
    -- Record counts by period
    LIST(CONCAT(period_sortable, ':', COUNT(*))) AS record_counts_by_period,
    -- Unique section counts by period
    LIST(CONCAT(period_sortable, ':', COUNT(DISTINCT CONCAT(
        CAST("Course Number" AS VARCHAR), '_',
        CAST("Section" AS VARCHAR), '_',
        CAST("Course Title" AS VARCHAR)
    )))) AS section_counts_by_period
FROM comprehensive_data
WHERE 
    "Instructor" IS NOT NULL AND
    "Course Number" IS NOT NULL AND
    "Section" IS NOT NULL AND
    "Course Title" IS NOT NULL
GROUP BY 
    faculty_id,
    "Instructor",
    "School",
    "E-Mail",
    "Department",
    "State";

-- Create course section records
DROP TABLE IF EXISTS course_section_records;
CREATE TABLE course_section_records AS
SELECT 
    "Course Number",
    "Section",
    "Course Title",
    "School",
    period_sortable,
    COUNT(*) as records_in_period,
    LIST(DISTINCT "Publisher") FILTER (WHERE "Publisher" IS NOT NULL) LIMIT 6 as publishers
FROM comprehensive_data
WHERE 
    "Course Number" IS NOT NULL AND
    "Section" IS NOT NULL AND
    "Course Title" IS NOT NULL AND
    "School" IS NOT NULL
GROUP BY 
    "Course Number",
    "Section",
    "Course Title",
    "School",
    period_sortable;

-- Create course records
DROP TABLE IF EXISTS course_records;
CREATE TABLE course_records AS
SELECT 
    "Course Number",
    "Course Title",
    "School",
    period_sortable,
    COUNT(DISTINCT "Section") as sections_in_period,
    SUM("Enrollments") as total_enrollment,
    LIST(DISTINCT "Publisher") FILTER (WHERE "Publisher" IS NOT NULL) LIMIT 6 as publishers
FROM comprehensive_data
WHERE 
    "Course Number" IS NOT NULL AND
    "Course Title" IS NOT NULL AND
    "School" IS NOT NULL
GROUP BY 
    "Course Number",
    "Course Title",
    "School",
    period_sortable; 