-- Create course section records
-- Group by course number, section, title within institution and date
-- Add publisher fields

CREATE TABLE IF NOT EXISTS course_section_records AS
WITH section_groups AS (
    SELECT 
        CONCAT("Institution", '_', "Course Number", '_', "Section", '_', "Course Title", '_', period_sortable) AS section_id,
        "Institution",
        "Course Number",
        "Section",
        "Course Title",
        period_sortable,
        MAX("Enrollment") AS enrollment,
        COUNT(*) AS records_merged,
        -- Extract publishers (up to 6)
        ARRAY_AGG(DISTINCT "Publisher") FILTER (WHERE "Publisher" IS NOT NULL AND "Publisher" != '') AS publishers
    FROM comprehensive_data
    GROUP BY 
        "Institution",
        "Course Number",
        "Section",
        "Course Title",
        period_sortable
)
SELECT 
    section_id,
    "Institution",
    "Course Number",
    "Section",
    "Course Title",
    period_sortable,
    enrollment,
    records_merged,
    -- Extract up to 6 publishers
    publishers[1] AS publisher_1,
    publishers[2] AS publisher_2,
    publishers[3] AS publisher_3,
    publishers[4] AS publisher_4,
    publishers[5] AS publisher_5,
    publishers[6] AS publisher_6
FROM section_groups;
