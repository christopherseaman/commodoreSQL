-- Export Texas Fall term records

${CONFIG}

-- Select all Texas Fall term records
SELECT
    "E-Mail",
    "Instructor",
    "FirstName",
    "LastName",
    "School",
    "Department",
    "State",
    "Course Number",
    "Section",
    "Course Title",
    "Enrollments",
    "Period",
    "period_sortable",
    "instnm",
    "sector",
    "iclevel",
    "control",
    "instsize"
FROM texas_fall_series
-- @PARTITION_BY: period_sortable
