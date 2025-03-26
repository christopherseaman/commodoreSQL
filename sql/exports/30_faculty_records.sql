-- Faculty records with explicit column selection
SELECT
    -- Primary faculty identification
    faculty_id,
    "Instructor",
    "E-Mail",
    
    -- Institution information
    "School",
    "Department",
    "State",
    
    -- Aggregated statistics
    record_counts_by_period,
    section_counts_by_period
    
FROM faculty_records;
-- @PARTITION_BY: School, Department 