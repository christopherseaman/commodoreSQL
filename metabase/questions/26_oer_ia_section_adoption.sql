-- name: OER/IA Section Adoption Over Time (2024+)
-- display: line
-- description: Share of course-sections with any OER / any Inclusive-Access material, by period (from master_section).

SELECT
    period_date,
    period_sortable,
    COUNT(*)                                                    AS sections,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_oer) / COUNT(*), 2) AS pct_oer,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_ia)  / COUNT(*), 2) AS pct_ia
FROM master_section
GROUP BY period_date, period_sortable
ORDER BY period_date
