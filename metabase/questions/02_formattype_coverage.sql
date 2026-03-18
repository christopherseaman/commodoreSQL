-- name: FormatType Coverage by Section (Filtered)
-- display: table
-- description: Per section, count of ISBNs with and without a non-null FormatType (filtered materials only)

SELECT
    section_id,
    COUNT(DISTINCT isbn13)                                                         AS total_isbns,
    COUNT(DISTINCT CASE WHEN "FormatType" IS NOT NULL THEN isbn13 END)             AS isbns_with_formattype,
    COUNT(DISTINCT CASE WHEN "FormatType" IS NULL     THEN isbn13 END)             AS isbns_missing_formattype,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN "FormatType" IS NOT NULL THEN isbn13 END)
              / NULLIF(COUNT(DISTINCT isbn13), 0),
        1
    )                                                                              AS formattype_pct
FROM comprehensive_data
WHERE filter_include = TRUE
GROUP BY section_id
ORDER BY isbns_missing_formattype DESC
