-- name: Raw Inferred-Required vs Not-Inferred Counts by Course Level and Period
-- display: table
-- description: Raw 2024+ catalog rows, by inferred-required flag, level, and term. Legacy raw diagnostic of the inferred-required flag, grouped by course level and period (2024+). The FALSE group means only "not inferred required": it also retains literal-required rows that fail the section-level inference rule, NULL statuses, supplies, placeholders, Canada, and other NoUse rows. This is not the canonical Use population or a release metric.

SELECT
    c.course_level,
    c.period_sortable,
    c.period_date,
    c.is_section_required_direct,
    COUNT(DISTINCT c.section_id)                                        AS sections,
    SUM(CASE WHEN c.is_required_inferred = TRUE  THEN 1 ELSE 0 END)           AS inferred_required_rows,
    SUM(CASE WHEN c.is_required_inferred = FALSE THEN 1 ELSE 0 END)           AS not_inferred_required_rows,
    COUNT(*)                                                             AS total_material_rows
FROM comprehensive_data c
WHERE c.period_date >= '2024-01-01'
GROUP BY c.course_level, c.period_sortable, c.period_date, c.is_section_required_direct
ORDER BY c.period_sortable DESC, c.course_level
