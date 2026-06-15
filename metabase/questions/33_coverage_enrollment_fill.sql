-- name: Coverage — Enrollment Fill-Potential (sections, 2024+)
-- display: table
-- description: Section-level enrollment coverage. Enrollment is NOT imputed — these counts show how many missing-enrollment sections have each fill signal available (has_enrollment_* are pure availability flags; here scoped to missing sections). Signals overlap (a section can have more than one), so the fillable rows do not sum to (missing − unfillable).
SELECT metric, sections,
       ROUND(100.0 * sections / (SELECT COUNT(*) FROM master_section), 2) AS pct_of_all_sections
FROM (
    SELECT 1 AS ord, 'has own enrollment'            AS metric, COUNT(*) FILTER (WHERE has_enrollment)          AS sections FROM master_section
    UNION ALL SELECT 2, 'missing enrollment',                   COUNT(*) FILTER (WHERE NOT has_enrollment)               FROM master_section
    UNION ALL SELECT 3, 'missing w/ sibling enrollment',        COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_sibling)       FROM master_section
    UNION ALL SELECT 4, 'missing w/ own seats_taken',           COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_own_seats)     FROM master_section
    UNION ALL SELECT 5, 'missing w/ sibling seats_taken',       COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_sibling_seats) FROM master_section
    UNION ALL SELECT 6, 'unfillable (no signal)',               COUNT(*) FILTER (WHERE NOT has_enrollment
                                                                   AND NOT has_enrollment_sibling
                                                                   AND NOT has_enrollment_own_seats
                                                                   AND NOT has_enrollment_sibling_seats)                FROM master_section
) ORDER BY ord
