-- Export faculty records with aggregated teaching activity
WITH faculty_counts AS (
    SELECT
        CASE
            WHEN email IS NOT NULL AND email != ''
            THEN email
            ELSE CONCAT(instructor, '_', school)
        END AS faculty_id,
        instructor,
        school,
        email,
        department,
        period_sortable,
        period_date,
        COUNT(*) AS record_count,
        COUNT(DISTINCT section_id) AS section_count
    FROM comprehensive_data
    WHERE
        instructor IS NOT NULL AND
        course_number IS NOT NULL AND
        section IS NOT NULL AND
        course_title IS NOT NULL
    GROUP BY
        faculty_id,
        instructor,
        school,
        email,
        department,
        period_sortable,
        period_date
)
SELECT
    faculty_id,
    instructor,
    school,
    email,
    department,
    LIST(CONCAT(period_sortable, ':', record_count)) AS record_counts_by_period,
    LIST(CONCAT(period_sortable, ':', section_count)) AS section_counts_by_period
FROM faculty_counts
GROUP BY
    faculty_id,
    instructor,
    school,
    email,
    department;
