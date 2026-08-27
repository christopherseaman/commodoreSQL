-- name: Sections with Not-Inferred-Required Rows by Course Level and Period (2024+)
-- display: table
-- description: Legacy raw diagnostic counting sections containing rows where is_required_inferred is FALSE, grouped by course level and period (2024+). FALSE means only "not inferred required": it also retains literal-required rows that fail the section-level inference rule, NULL statuses, supplies, placeholders, Canada, and other NoUse rows. This is not a count of sections with no materials and is not the canonical Use population or a release metric.

SELECT
    c.course_level,
    c.period_sortable,
    c.period_date,
    s.has_required,
    COUNT(DISTINCT c.section_id)  AS sections_with_not_inferred_required_rows,
    COUNT(DISTINCT c.course_id)   AS courses_affected
FROM comprehensive_data c
JOIN section_book_status s ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
  AND c.is_required_inferred = FALSE
GROUP BY c.course_level, c.period_sortable, c.period_date, s.has_required
ORDER BY c.period_sortable DESC, sections_with_not_inferred_required_rows DESC
