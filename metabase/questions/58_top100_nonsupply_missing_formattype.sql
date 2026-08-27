-- name: Top 100 Non-Supply ISBNs Missing FormatType (Fall 2025)
-- display: table
-- description: Issue #42. FormatType-enrichment candidates: raw Fall-2025 comprehensive_data rows with non-null ISBN13, NOT is_supply, and empty FormatType (NULL or ''). Canada and NoUse rows remain included; no canonical #58 Use filter is applied. Ranked by distinct section_id adoption count — the highest-leverage ISBNs to manually classify first. Same period scope as #37 (card 157); reuses its ISBN13/Title/Author grain. Scope population: 166,836 distinct non-supply ISBNs with empty FormatType, touching 822,303 distinct section adoptions and 1,204,681 catalog rows; this top 100 alone covers 87,291 of those section adoptions (~10.6%). Most rows are legitimate textbooks/references never assigned a FormatType (nursing, writing-handbook, and clinical-reference titles dominate); a handful are data-quality noise worth flagging separately rather than enriching — e.g. ISBN13 9780000043856 (blank Title/Author, a placeholder-looking ISBN) and 9789781111112 ("This Is A Digital Textbook..." with Author "Download This Text From Your D2l Acct", clearly a catalog placeholder, not a real ISBN lookup target).
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
