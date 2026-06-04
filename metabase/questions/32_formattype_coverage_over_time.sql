-- name: FormatType Classification Coverage Over Time (2024+)
-- display: line
-- description: Share of materials that carry a FormatType (and are thus OER/IA-classifiable). Coverage falls 73%→57% over 2024-1..2025-4 — which is WHY absolute OER/IA counts decline even though the rate-among-classified is flat. Pair with "OER/IA Rate Among Classified Materials".

SELECT
    period_date,
    period_sortable,
    COUNT(*) AS material_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE FormatType IS NOT NULL AND FormatType <> '') / COUNT(*), 2) AS pct_formattype_present
FROM comprehensive_data
WHERE period_date >= '2024-01-01' AND ISBN13 IS NOT NULL
GROUP BY period_date, period_sortable
ORDER BY period_date
