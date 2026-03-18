-- name: Material Counts by Section (Included vs Excluded)
-- display: table
-- description: Per section, counts of materials included and excluded by the has_required filter (2024+)

SELECT
    s.section_id,
    s.has_required,
    COUNT(*)                                                             AS total_materials,
    SUM(CASE WHEN c.filter_include = TRUE  THEN 1 ELSE 0 END)           AS included_materials,
    SUM(CASE WHEN c.filter_include = FALSE THEN 1 ELSE 0 END)           AS excluded_materials
FROM comprehensive_data c
JOIN section_book_status s ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
GROUP BY c.section_id, s.has_required
ORDER BY excluded_materials DESC
