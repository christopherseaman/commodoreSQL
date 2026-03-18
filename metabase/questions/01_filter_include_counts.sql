-- name: Material Counts by has_required (Included vs Excluded)
-- display: table
-- description: Summary of included vs excluded materials grouped by has_required flag (2024+)

SELECT
    s.has_required,
    COUNT(DISTINCT c.section_id)                                       AS sections,
    SUM(CASE WHEN c.filter_include = TRUE  THEN 1 ELSE 0 END)          AS included_materials,
    SUM(CASE WHEN c.filter_include = FALSE THEN 1 ELSE 0 END)          AS excluded_materials,
    COUNT(*)                                                            AS total_materials
FROM comprehensive_data c
JOIN section_book_status s ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
GROUP BY s.has_required
ORDER BY s.has_required DESC
