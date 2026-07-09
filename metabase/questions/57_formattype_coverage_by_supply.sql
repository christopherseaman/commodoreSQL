-- name: FormatType Coverage by Supply Status (2024+)
-- display: table
-- description: Issue #42. FormatType fill rate split by is_supply (#36), over the same 2024+/ISBN13-not-null scope as cards 02_formattype_coverage and 32_formattype_coverage_over_time. Empty FormatType = NULL or ''. share_of_all_empty_formattype_rows/isbns show how much of the overall gap each segment explains: supplies are a small slice -- 1.47% of empty-FormatType rows (72,587 of 4,945,299) and 0.70% of empty-FormatType distinct ISBNs (2,371 of 340,532). Supplies themselves are less well filled per-row (75.05% of supply rows empty vs 34.62% non-supply) and per-ISBN (94.09% of the 2,520 supply ISBNs never carry a FormatType vs 51.11% non-supply). Surprising bit: 149 of 2,520 supply ISBNs (5.91%) DO carry a FormatType -- mostly science_lab/art_drafting kits recorded as Book or Bundle (bundled with a textbook).
WITH base AS (
    SELECT "ISBN13", is_supply, "FormatType"
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND "ISBN13" IS NOT NULL
),
totals AS (
    SELECT
        COUNT(*) FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') AS all_empty_rows,
        COUNT(DISTINCT "ISBN13") FILTER (WHERE "FormatType" IS NULL OR "FormatType" = '') AS all_empty_isbns
    FROM base
)
SELECT 1 AS ord, 'All ISBNs (2024+)' AS segment,
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
