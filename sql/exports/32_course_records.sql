-- Course records with explicit column selection
SELECT
    -- Course identification
    "Course Number",
    "Course Title",
    
    -- Institution information
    "School",
    
    -- Time information
    period_sortable,
    
    -- Aggregated statistics
    sections_in_period,
    total_enrollment,
    publishers
    
FROM course_records;
