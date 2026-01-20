-- Course section records with explicit column selection
SELECT
    -- Course identification
    "Course Number",
    "Section",
    "Course Title",
    
    -- Institution information
    "School",
    
    -- Time information
    period_sortable,
    
    -- Aggregated statistics
    records_in_period,
    publishers
    
FROM course_section_records
-- @PARTITION_BY: period_sortable
