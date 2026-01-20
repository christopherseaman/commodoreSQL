-- Current mailing list (last 3 years / 12 periods) with panel response data
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
    unit_id,
    panel_response_year
FROM current_mailing;
