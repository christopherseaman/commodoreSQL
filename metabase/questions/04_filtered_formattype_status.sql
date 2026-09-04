-- name: FormatType x OER x IA x Status (Filtered, 2024+)
-- display: table
-- description: Canonical inferred-required items; enrollment counted once per section/group. FormatType cross-tabulated with OER/IA flags and book_status over canonical inferred-required items. Item counts use material_costs grain; total_enrollments counts each section once within a displayed group.

WITH items AS MATERIALIZED (
    SELECT
        format_type,
        is_oer,
        is_ia,
        book_status,
        isbn13,
        section_id,
        enrollments
    FROM material_costs
    WHERE is_required_inferred = TRUE
),
item_rollup AS (
    SELECT
        format_type,
        is_oer,
        is_ia,
        book_status,
        COUNT(*) AS record_count,
        COUNT(DISTINCT isbn13) AS unique_materials,
        COUNT(DISTINCT section_id) AS sections
    FROM items
    GROUP BY format_type, is_oer, is_ia, book_status
),
section_enrollment_rollup AS (
    SELECT
        format_type,
        is_oer,
        is_ia,
        book_status,
        SUM(enrollments) AS total_enrollments
    FROM (
        SELECT
            format_type,
            is_oer,
            is_ia,
            book_status,
            section_id,
            ANY_VALUE(enrollments) AS enrollments
        FROM items
        GROUP BY format_type, is_oer, is_ia, book_status, section_id
    ) section_groups
    GROUP BY format_type, is_oer, is_ia, book_status
)
SELECT
    COALESCE(items.format_type, '(empty/NULL)') AS format_type,
    items.is_oer,
    items.is_ia,
    COALESCE(items.book_status, '(empty/NULL)') AS book_status,
    items.record_count,
    ROUND(100.0 * items.record_count
          / SUM(items.record_count) OVER (PARTITION BY items.format_type), 2)
        AS percent_within_format,
    ROUND(100.0 * items.record_count
          / SUM(items.record_count) OVER (PARTITION BY items.book_status), 2)
        AS percent_within_status,
    items.unique_materials,
    items.sections,
    enrollment.total_enrollments
FROM item_rollup items
LEFT JOIN section_enrollment_rollup enrollment
  ON enrollment.format_type IS NOT DISTINCT FROM items.format_type
 AND enrollment.is_oer IS NOT DISTINCT FROM items.is_oer
 AND enrollment.is_ia IS NOT DISTINCT FROM items.is_ia
 AND enrollment.book_status IS NOT DISTINCT FROM items.book_status
ORDER BY items.format_type, items.book_status, items.is_oer DESC, items.is_ia DESC
