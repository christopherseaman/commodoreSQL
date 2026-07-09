-- name: Top 100 Non-Supply ISBNs Missing FormatType (Fall 2025)
-- display: table
-- description: Issue #42. FormatType-enrichment candidates: non-supply (#36) ISBNs with empty FormatType (NULL or '') in Fall 2025 (period_sortable='2025-4'), ranked by distinct section_id adoption count. Scope population: 166,836 distinct non-supply ISBNs with empty FormatType, touching 822,303 distinct section adoptions and 1,204,681 catalog rows; this top 100 alone covers 87,291 of those section adoptions (~10.6%). Most rows are legitimate textbooks/references never assigned a FormatType (nursing, writing-handbook, clinical-reference titles dominate); a handful are catalog-placeholder noise (e.g. ISBN13 9780000043856, blank Title/Author) left in for human triage rather than pre-filtered.
SELECT
    c."ISBN13", c."Title", c."Author",
    COUNT(DISTINCT c.section_id) AS section_count,
    COUNT(*) AS row_count
FROM comprehensive_data c
WHERE c.period_sortable = '2025-4'
  AND c."ISBN13" IS NOT NULL
  AND NOT c.is_supply
  AND (c."FormatType" IS NULL OR c."FormatType" = '')
GROUP BY c."ISBN13", c."Title", c."Author"
ORDER BY section_count DESC, row_count DESC
LIMIT 100
