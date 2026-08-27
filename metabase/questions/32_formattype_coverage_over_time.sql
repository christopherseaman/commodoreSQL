-- name: FormatType Classification Coverage Over Time (2024+)
-- display: line
-- description: Share of canonical Use materials that carry a FormatType (and are thus OER/IA-classifiable). Coverage falls from 75.27% in 2024-1 to 57.86% in 2025-4; pair with "OER/IA Rate Among Classified Materials".

SELECT
    period_date,
    period_sortable,
    COUNT(*) AS material_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE FormatType IS NOT NULL AND FormatType <> '') / COUNT(*), 2) AS pct_formattype_present
FROM comprehensive_data
WHERE is_course_material_use
GROUP BY period_date, period_sortable
ORDER BY period_date
