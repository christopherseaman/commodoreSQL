-- name: FormatType x OER x IA x Status (Filtered, 2024+)
-- display: table
-- description: FormatType cross-tabulated with OER/IA flags and book_status — filtered materials only (has_required logic, period >= 2024)

SELECT
    COALESCE("FormatType", '(empty/NULL)')   AS format_type,
    is_oer,
    is_ia,
    COALESCE(book_status, '(empty/NULL)')    AS book_status,
    COUNT(*)                                  AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY "FormatType"), 2) AS percent_within_format,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY book_status),  2) AS percent_within_status,
    COUNT(DISTINCT isbn13)                    AS unique_materials,
    COUNT(DISTINCT section_id)                AS sections,
    SUM(enrollments)                          AS total_enrollments
FROM comprehensive_data
WHERE filter_include = TRUE
GROUP BY "FormatType", is_oer, is_ia, book_status
ORDER BY format_type, book_status, is_oer DESC, is_ia DESC
