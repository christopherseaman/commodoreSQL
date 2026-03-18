-- name: Material Counts by Course Level and Period (Included vs Excluded)
-- display: table
-- description: Included vs excluded material counts grouped by course level and period (2024+)

SELECT
    c.course_level,
    c.period_sortable,
    c.period_date,
    s.has_required,
    COUNT(DISTINCT c.section_id)                                        AS sections,
    SUM(CASE WHEN c.filter_include = TRUE  THEN 1 ELSE 0 END)           AS included_materials,
    SUM(CASE WHEN c.filter_include = FALSE THEN 1 ELSE 0 END)           AS excluded_materials,
    COUNT(*)                                                             AS total_materials
FROM comprehensive_data c
JOIN section_book_status s ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
GROUP BY c.course_level, c.period_sortable, c.period_date, s.has_required
ORDER BY c.period_sortable DESC, c.course_level
