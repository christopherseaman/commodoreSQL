-- name: Sections with No Included Materials by Course Level and Period (2024+)
-- display: table
-- description: Count of sections with no included materials after has_required filter, grouped by course level and period

SELECT
    c.course_level,
    c.period_sortable,
    c.period_date,
    s.has_required,
    COUNT(DISTINCT c.section_id)  AS sections_no_materials,
    COUNT(DISTINCT c.course_id)   AS courses_affected
FROM comprehensive_data c
JOIN section_book_status s ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
  AND c.is_required_inferred = FALSE
GROUP BY c.course_level, c.period_sortable, c.period_date, s.has_required
ORDER BY c.period_sortable DESC, sections_no_materials DESC
