-- name: Coverage & Scope — Complete Section Enrollment by Term
-- display: table
-- description: Complete valid recent-term section spine from comprehensive_data. Raw/assigned enrollment remain distinct. The full section denominator is deduplicated before aggregation; canonical_material_bearing_section_count is a separately named comparison to retained master_section rows.

WITH full_section_context AS (
    SELECT DISTINCT
        period_sortable,
        section_id,
        section_course_id AS course_id,
        section_enrollments AS enrollments,
        section_enrollment_assigned AS enrollment_assigned,
        section_enrollment_source AS enrollment_source
    FROM comprehensive_data
    WHERE period_sortable IS NOT NULL
      AND section_id IS NOT NULL
      AND is_recent
[[ AND {{period_sortable}} ]]
)
SELECT
    full_section_context.period_sortable,
    COUNT(*) AS complete_spine_section_count,
    COUNT(DISTINCT full_section_context.course_id) AS complete_spine_course_count,
    COUNT(*) FILTER (WHERE full_section_context.enrollments IS NOT NULL) AS raw_enrollment_section_count,
    SUM(full_section_context.enrollments) FILTER (WHERE full_section_context.enrollments IS NOT NULL)
        AS raw_enrollment_total,
    COUNT(*) FILTER (WHERE full_section_context.enrollment_assigned IS NOT NULL)
        AS assigned_enrollment_section_count,
    SUM(full_section_context.enrollment_assigned) FILTER (WHERE full_section_context.enrollment_assigned IS NOT NULL)
        AS assigned_enrollment_total,
    COUNT(*) FILTER (WHERE full_section_context.enrollment_source = 'own') AS source_own_section_count,
    COUNT(*) FILTER (WHERE full_section_context.enrollment_source = 'own_seats') AS source_own_seats_section_count,
    COUNT(*) FILTER (WHERE full_section_context.enrollment_source = 'sibling_enroll') AS source_sibling_enroll_section_count,
    COUNT(*) FILTER (WHERE full_section_context.enrollment_source = 'sibling_seats') AS source_sibling_seats_section_count,
    COUNT(*) FILTER (WHERE full_section_context.enrollment_source = 'class_median') AS source_class_median_section_count,
    COUNT(*) FILTER (WHERE full_section_context.enrollment_source = 'level_median') AS source_level_median_section_count,
    COUNT(*) FILTER (WHERE full_section_context.enrollment_source = 'none') AS source_none_section_count,
    COUNT(*) FILTER (
        WHERE full_section_context.enrollment_source NOT IN (
            'own', 'own_seats', 'sibling_enroll', 'sibling_seats',
            'class_median', 'level_median', 'none'
        ) OR full_section_context.enrollment_source IS NULL
    ) AS source_other_or_null_section_count,
    COUNT(master_section.section_id) AS canonical_material_bearing_section_count,
    ROUND(100.0 * COUNT(master_section.section_id) / NULLIF(COUNT(*), 0), 2)
        AS pct_canonical_material_bearing_of_complete_spine_sections,
    ROUND(100.0 * COUNT(*) FILTER (WHERE full_section_context.enrollments IS NOT NULL)
        / NULLIF(COUNT(*), 0), 2) AS pct_raw_enrollment_of_complete_spine_sections,
    ROUND(100.0 * COUNT(*) FILTER (WHERE full_section_context.enrollment_assigned IS NOT NULL)
        / NULLIF(COUNT(*), 0), 2) AS pct_assigned_enrollment_of_complete_spine_sections
FROM full_section_context
LEFT JOIN master_section
  ON full_section_context.period_sortable = master_section.period_sortable
 AND full_section_context.section_id = master_section.section_id
GROUP BY full_section_context.period_sortable
ORDER BY full_section_context.period_sortable
