-- Aggregate and transform records by faculty, course sections, and courses

${CONFIG}

-- Generate faculty records with aggregated metrics
DROP VIEW IF EXISTS faculty_records;
CREATE VIEW faculty_records AS
WITH faculty_counts AS (
    -- Uniquely identify faculty by email or name+school
    SELECT 
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
        period_sortable,
        COUNT(*) AS record_count,
        COUNT(DISTINCT CONCAT(
            CAST("Course Number" AS VARCHAR), '_',
            CAST("Section" AS VARCHAR), '_',
            CAST("Course Title" AS VARCHAR)
        )) AS section_count
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
        "State",
        period_sortable
)
SELECT 
    faculty_id,
    "Instructor",
    "School",
    "E-Mail",
    "Department",
    "State",
    -- Aggregate record and section counts by period
    LIST(CONCAT(period_sortable, ':', record_count)) AS record_counts_by_period,
    LIST(CONCAT(period_sortable, ':', section_count)) AS section_counts_by_period
FROM faculty_counts
GROUP BY 
    faculty_id,
    "Instructor",
    "School",
    "E-Mail",
    "Department",
    "State";

-- Create course section records with period-based metrics
DROP VIEW IF EXISTS course_section_records;
CREATE VIEW course_section_records AS
SELECT 
    "Course Number",
    "Section",
    "Course Title",
    "School",
    period_sortable,
    COUNT(*) as records_in_period,
    LIST(DISTINCT "Publisher") FILTER (WHERE "Publisher" IS NOT NULL) AS publishers
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

-- Generate course records with aggregated enrollment and section data
DROP VIEW IF EXISTS course_records;
CREATE VIEW course_records AS
SELECT 
    "Course Number",
    "Course Title",
    "School",
    period_sortable,
    COUNT(DISTINCT "Section") as sections_in_period,
    SUM("Enrollments") as total_enrollment,
    LIST(DISTINCT "Publisher") FILTER (WHERE "Publisher" IS NOT NULL) AS publishers
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
