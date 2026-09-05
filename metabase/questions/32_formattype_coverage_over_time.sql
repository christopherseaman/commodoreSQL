-- name: FormatType Classification Coverage Over Time (2024+)
-- display: line
-- description: All canonical master_material items; fraction with FormatType. Share of canonical deduplicated master_material items that carry a FormatType (and are thus OER/IA-classifiable). Pair with "OER/IA Rate Among Classified Materials".

SELECT
    period_date,
    period_sortable,
    COUNT(*) AS material_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE format_type IS NOT NULL AND format_type <> '') / COUNT(*), 2) AS pct_formattype_present
FROM master_material
WHERE 1 = 1
[[ AND {{period_sortable}} ]]
GROUP BY period_date, period_sortable
ORDER BY period_date
