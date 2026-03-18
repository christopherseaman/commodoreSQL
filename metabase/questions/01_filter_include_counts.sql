-- name: Material Counts by Section (Included vs Excluded)
-- display: table
-- description: Per section, counts of materials included and excluded by the has_required filter (2024+)

SELECT
    s.section_id,
    s.has_required,
    COUNT(*)                                                             AS total_materials,
    SUM(CASE WHEN c.filter_include = TRUE  THEN 1 ELSE 0 END)           AS included_materials,
    SUM(CASE WHEN c.filter_include = FALSE THEN 1 ELSE 0 END)           AS excluded_materials
FROM section_book_status s
JOIN course_catalog_20251215 c ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
GROUP BY s.section_id, s.has_required
ORDER BY excluded_materials DESC
