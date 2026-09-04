-- name: Coverage & Scope — Complete Section Enrollment by Term
-- display: table
-- description: Complete valid 2024+ section_enrollment spine; raw/assigned enrollment distinguished. Current-snapshot enrollment coverage over the complete valid 2024+ section_enrollment spine, where section_count is the full section denominator and raw versus assigned enrollment remain distinct. The enrollment_source columns count assignment provenance. canonical_material_bearing_section_count is a separately named comparison to retained master_section rows and is not the full-spine denominator.

SELECT
    section_enrollment.period_sortable,
    COUNT(*) AS complete_spine_section_count,
    COUNT(DISTINCT section_enrollment.course_id) AS complete_spine_course_count,
    COUNT(*) FILTER (WHERE section_enrollment.enrollments IS NOT NULL) AS raw_enrollment_section_count,
    SUM(section_enrollment.enrollments) FILTER (WHERE section_enrollment.enrollments IS NOT NULL)
        AS raw_enrollment_total,
    COUNT(*) FILTER (WHERE section_enrollment.enrollment_assigned IS NOT NULL)
        AS assigned_enrollment_section_count,
    SUM(section_enrollment.enrollment_assigned) FILTER (WHERE section_enrollment.enrollment_assigned IS NOT NULL)
        AS assigned_enrollment_total,
    COUNT(*) FILTER (WHERE section_enrollment.enrollment_source = 'own') AS source_own_section_count,
    COUNT(*) FILTER (WHERE section_enrollment.enrollment_source = 'own_seats') AS source_own_seats_section_count,
    COUNT(*) FILTER (WHERE section_enrollment.enrollment_source = 'sibling_enroll') AS source_sibling_enroll_section_count,
    COUNT(*) FILTER (WHERE section_enrollment.enrollment_source = 'sibling_seats') AS source_sibling_seats_section_count,
    COUNT(*) FILTER (WHERE section_enrollment.enrollment_source = 'class_median') AS source_class_median_section_count,
    COUNT(*) FILTER (WHERE section_enrollment.enrollment_source = 'level_median') AS source_level_median_section_count,
    COUNT(*) FILTER (WHERE section_enrollment.enrollment_source = 'none') AS source_none_section_count,
    COUNT(*) FILTER (
        WHERE section_enrollment.enrollment_source NOT IN (
            'own', 'own_seats', 'sibling_enroll', 'sibling_seats',
            'class_median', 'level_median', 'none'
        ) OR section_enrollment.enrollment_source IS NULL
    ) AS source_other_or_null_section_count,
    COUNT(master_section.section_id) AS canonical_material_bearing_section_count,
    ROUND(100.0 * COUNT(master_section.section_id) / NULLIF(COUNT(*), 0), 2)
        AS pct_canonical_material_bearing_of_complete_spine_sections,
    ROUND(100.0 * COUNT(*) FILTER (WHERE section_enrollment.enrollments IS NOT NULL)
        / NULLIF(COUNT(*), 0), 2) AS pct_raw_enrollment_of_complete_spine_sections,
    ROUND(100.0 * COUNT(*) FILTER (WHERE section_enrollment.enrollment_assigned IS NOT NULL)
        / NULLIF(COUNT(*), 0), 2) AS pct_assigned_enrollment_of_complete_spine_sections
FROM section_enrollment
LEFT JOIN master_section
  ON section_enrollment.period_sortable = master_section.period_sortable
 AND section_enrollment.section_id = master_section.section_id
WHERE TRY_CAST(SPLIT_PART(section_enrollment.period_sortable, '-', 1) AS INTEGER) >= 2024
[[ AND {{period_sortable}} ]]
GROUP BY section_enrollment.period_sortable
ORDER BY section_enrollment.period_sortable
