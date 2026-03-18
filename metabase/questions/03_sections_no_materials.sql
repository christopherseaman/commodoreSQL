-- name: Sections with No Included Materials — Summary (2024+)
-- display: table
-- description: Count of sections with no included materials after has_required filter, grouped by school and has_required flag

SELECT
    c.school,
    s.has_required,
    COUNT(DISTINCT c.section_id)  AS sections_no_materials,
    COUNT(DISTINCT c.course_id)   AS courses_affected,
    COUNT(DISTINCT c.period)      AS periods_seen
FROM comprehensive_data c
JOIN section_book_status s ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
  AND c.filter_include = FALSE
GROUP BY c.school, s.has_required
ORDER BY sections_no_materials DESC
