-- name: Coverage — Enrollment Fill-Potential (sections, 2024+)
-- display: table
-- description: Enrollment coverage among material-bearing Master Section rows. Enrollment is NOT imputed here — these counts show how many retained sections missing enrollment have each fill signal available (has_enrollment_* are pure availability flags). Signals overlap (a section can have more than one), so the fillable rows do not sum to (missing − unfillable). pct_of_all_sections means all material-bearing sections in this model, not the complete section_enrollment population.
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
