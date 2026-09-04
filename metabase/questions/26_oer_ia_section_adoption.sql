-- name: OER/IA Section Adoption Over Time (2024+)
-- display: line
-- description: Material-bearing Master Section denominator; any canonical OER/IA item. Share of material-bearing course sections with any OER / any Inclusive-Access canonical item, by period (from master_section). This is not a full section_enrollment denominator.

SELECT
    period_date,
    period_sortable,
    COUNT(*)                                                    AS sections,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_oer) / COUNT(*), 2) AS pct_oer,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_ia)  / COUNT(*), 2) AS pct_ia
FROM master_section
GROUP BY period_date, period_sortable
ORDER BY period_date
