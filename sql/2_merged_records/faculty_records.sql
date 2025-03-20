-- Create faculty records
-- Group by email or name within institution
-- Create indicators for record counts by date

CREATE TABLE IF NOT EXISTS faculty_records AS
WITH faculty_groups AS (
    -- Group by email if available, otherwise by name within institution
    SELECT 
        CASE 
            WHEN "E-Mail" IS NOT NULL AND "E-Mail" != '' 
            THEN "E-Mail" 
            ELSE CONCAT("Faculty Name", '_', "Institution") 
        END AS faculty_id,
        "Faculty Name",
        "Institution",
        "E-Mail",
        "Department",
        "Title",
        -- Take the most recent record's details
        FIRST_VALUE("State") OVER (
            PARTITION BY 
                CASE 
                    WHEN "E-Mail" IS NOT NULL AND "E-Mail" != '' 
                    THEN "E-Mail" 
                    ELSE CONCAT("Faculty Name", '_', "Institution") 
                END
            ORDER BY period_sortable DESC
        ) AS State,
        -- Extract the period (YYYY-N)
        period_sortable,
        -- Count records per faculty per period
        COUNT(*) OVER (
            PARTITION BY 
                CASE 
                    WHEN "E-Mail" IS NOT NULL AND "E-Mail" != '' 
                    THEN "E-Mail" 
                    ELSE CONCAT("Faculty Name", '_', "Institution") 
                END,
                period_sortable
        ) AS records_in_period,
        -- Count unique course sections per faculty per period
        COUNT(DISTINCT CONCAT("Course Number", '_', "Section", '_', "Course Title")) OVER (
            PARTITION BY 
                CASE 
                    WHEN "E-Mail" IS NOT NULL AND "E-Mail" != '' 
                    THEN "E-Mail" 
                    ELSE CONCAT("Faculty Name", '_', "Institution") 
                END,
                period_sortable
        ) AS unique_sections_in_period
    FROM comprehensive_data
),
-- Get the most recent record for each faculty member
faculty_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY faculty_id
            ORDER BY period_sortable DESC
        ) AS rank
    FROM faculty_groups
)
SELECT 
    faculty_id,
    "Faculty Name",
    "Institution",
    "E-Mail",
    "Department",
    "Title",
    State,
    -- Create a string with counts by period
    LIST(CONCAT(period_sortable, ':', records_in_period)) AS record_counts_by_period,
    LIST(CONCAT(period_sortable, ':', unique_sections_in_period)) AS section_counts_by_period
FROM faculty_latest
WHERE rank = 1
GROUP BY 
    faculty_id,
    "Faculty Name",
    "Institution",
    "E-Mail",
    "Department",
    "Title",
    State;
