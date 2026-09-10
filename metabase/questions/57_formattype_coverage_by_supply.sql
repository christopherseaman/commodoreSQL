-- name: FormatType Coverage by Supply Status (Recent)
-- display: table
-- description: Raw recent-term ISBN-bearing catalog rows, by supply status; no Use filter. Issue #42. FormatType fill rate split by is_supply (#36) over raw comprehensive_data rows in recent terms with non-null ISBN13. Canada and NoUse rows remain included; no canonical #58 Use filter is applied. Empty FormatType = NULL or ''. Row denominators are all rows in this scope; ISBN denominators are distinct ISBN13s in this scope. Historical fill-rate totals are intentionally not embedded because the rolling scope changes with each release.
WITH base AS (
    SELECT "ISBN13", is_supply, "FormatType"
    FROM comprehensive_data
    WHERE is_recent AND "ISBN13" IS NOT NULL
    [[ AND {{period_sortable}} ]]
),
totals AS (
    SELECT
        COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') AS all_empty_rows,
        COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') AS all_empty_isbns
    FROM base
)
SELECT 1 AS ord, 'All ISBNs (recent terms)' AS segment,
       COUNT(*) AS row_count,
       COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') AS empty_formattype_rows,
       ROUND(100.0 * COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / COUNT(*), 2) AS pct_rows_empty_formattype,
       COUNT(DISTINCT "ISBN13") AS isbn_count,
       COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') AS empty_formattype_isbns,
       ROUND(100.0 * COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / COUNT(DISTINCT "ISBN13"), 2) AS pct_isbns_empty_formattype,
       100.0 AS share_of_all_empty_formattype_rows_pct,
       100.0 AS share_of_all_empty_formattype_isbns_pct
FROM base
UNION ALL
SELECT 2, 'Non-supply ISBNs',
       COUNT(*),
       COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = ''),
       ROUND(100.0 * COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / COUNT(*), 2),
       COUNT(DISTINCT "ISBN13"),
       COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = ''),
       ROUND(100.0 * COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / COUNT(DISTINCT "ISBN13"), 2),
       ROUND(100.0 * COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / (SELECT all_empty_rows FROM totals), 3),
       ROUND(100.0 * COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / (SELECT all_empty_isbns FROM totals), 3)
FROM base WHERE NOT is_supply
UNION ALL
SELECT 3, 'Supply ISBNs',
       COUNT(*),
       COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = ''),
       ROUND(100.0 * COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / COUNT(*), 2),
       COUNT(DISTINCT "ISBN13"),
       COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = ''),
       ROUND(100.0 * COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / COUNT(DISTINCT "ISBN13"), 2),
       ROUND(100.0 * COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / (SELECT all_empty_rows FROM totals), 3),
       ROUND(100.0 * COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') / (SELECT all_empty_isbns FROM totals), 3)
FROM base WHERE is_supply
ORDER BY ord
