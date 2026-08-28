-- name: FormatType Coverage by Course Level and Period (Filtered)
-- display: table
-- description: FormatType null coverage grouped by course level and period (canonical Use materials, inferred-required only)

SELECT
    c.course_level,
    c.period_sortable,
    c.period_date,
    COUNT(DISTINCT c.isbn13)                                                          AS total_isbns,
    COUNT(DISTINCT CASE WHEN c.format_type IS NOT NULL THEN c.isbn13 END)              AS isbns_with_formattype,
    COUNT(DISTINCT CASE WHEN c.format_type IS NULL     THEN c.isbn13 END)              AS isbns_missing_formattype,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN c.format_type IS NOT NULL THEN c.isbn13 END)
              / NULLIF(COUNT(DISTINCT c.isbn13), 0),
        1
    )                                                                                 AS formattype_pct
FROM material_costs c
WHERE c.is_required_inferred = TRUE
GROUP BY c.course_level, c.period_sortable, c.period_date
ORDER BY c.period_sortable DESC, c.course_level
