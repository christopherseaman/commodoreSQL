-- Master mailing list with explicit column selection
SELECT
    email,
    instructor,
    first_name,
    last_name,
    school,
    department,
    course_level,
    course_subject,
    period,
    period_sortable,
    unit_id
FROM master_mailing;
