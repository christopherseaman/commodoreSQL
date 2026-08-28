-- name: OER/IA Rate Among Classified Materials (2024+)
-- display: line
-- description: OER/IA as a share of canonical Use materials that HAVE a FormatType classification (denominator excludes unclassified).

SELECT
    period_date,
    period_sortable,
    COUNT(*) FILTER (WHERE is_ia IS NOT NULL) AS classified_materials,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_oer) / NULLIF(COUNT(*) FILTER (WHERE is_oer IS NOT NULL), 0), 2) AS pct_oer_of_classified,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_ia)  / NULLIF(COUNT(*) FILTER (WHERE is_ia  IS NOT NULL), 0), 2) AS pct_ia_of_classified
FROM material_costs
WHERE has_formattype
GROUP BY period_date, period_sortable
ORDER BY period_date
