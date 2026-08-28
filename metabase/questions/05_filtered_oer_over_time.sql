-- name: OER/IA Adoption Over Time (Filtered, 2024+)
-- display: line
-- description: OER and IA item counts by period over canonical inferred-required material_costs rows. total_enrollments counts each section once within its displayed OER/IA group.

WITH items AS MATERIALIZED (
    SELECT
        period_date,
        period_sortable,
        is_oer,
        is_ia,
        isbn13,
        section_id,
        unit_id,
        enrollments
    FROM material_costs
    WHERE is_required_inferred = TRUE
),
item_rollup AS (
    SELECT
        period_date,
        period_sortable,
        is_oer,
        is_ia,
        COUNT(*) AS record_count,
        COUNT(DISTINCT isbn13) AS unique_materials,
        COUNT(DISTINCT section_id) AS sections,
        COUNT(DISTINCT unit_id) AS institutions
    FROM items
    GROUP BY period_date, period_sortable, is_oer, is_ia
),
section_enrollment_rollup AS (
    SELECT
        period_date,
        period_sortable,
        is_oer,
        is_ia,
        SUM(enrollments) AS total_enrollments
    FROM (
        SELECT
            period_date,
            period_sortable,
            is_oer,
            is_ia,
            section_id,
            ANY_VALUE(enrollments) AS enrollments
        FROM items
        GROUP BY period_date, period_sortable, is_oer, is_ia, section_id
    ) section_groups
    GROUP BY period_date, period_sortable, is_oer, is_ia
)
SELECT
    items.period_date,
    items.period_sortable,
    items.is_oer,
    items.is_ia,
    items.record_count,
    items.unique_materials,
    items.sections,
    items.institutions,
    enrollment.total_enrollments
FROM item_rollup items
LEFT JOIN section_enrollment_rollup enrollment
  ON enrollment.period_date = items.period_date
 AND enrollment.period_sortable = items.period_sortable
 AND enrollment.is_oer IS NOT DISTINCT FROM items.is_oer
 AND enrollment.is_ia IS NOT DISTINCT FROM items.is_ia
ORDER BY items.period_date, items.is_oer DESC, items.is_ia DESC
