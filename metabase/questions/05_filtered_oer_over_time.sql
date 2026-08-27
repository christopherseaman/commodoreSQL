-- name: OER/IA Adoption Over Time (Filtered, 2024+)
-- display: line
-- description: OER and IA record counts by period — canonical Use materials, inferred-required only (period >= 2024)

SELECT
    period_date,
    period_sortable,
    is_oer,
    is_ia,
    COUNT(*)                   AS record_count,
    COUNT(DISTINCT isbn13)     AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT unit_id)    AS institutions,
    SUM(enrollments)           AS total_enrollments
FROM comprehensive_data
WHERE is_course_material_use
  AND is_required_inferred = TRUE
GROUP BY period_date, period_sortable, is_oer, is_ia
ORDER BY period_date, is_oer DESC, is_ia DESC
