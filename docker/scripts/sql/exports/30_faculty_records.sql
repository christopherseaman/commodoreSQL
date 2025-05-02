-- Select faculty records for export
SELECT
    faculty_id,
    "Instructor",
    "E-Mail",
    "School",
    "Department",
    "State",
    record_counts_by_period,
    section_counts_by_period
FROM faculty_records
