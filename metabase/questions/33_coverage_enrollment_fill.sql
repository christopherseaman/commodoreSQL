-- name: Coverage — Enrollment Fill-Potential (sections, 2024+)
-- display: table
-- description: Section-level enrollment coverage. Enrollment is NOT imputed — these counts show how many missing-enrollment sections COULD be filled from each signal. Flags overlap (a section can be fillable from more than one), so the fill rows do not sum to (missing − unfillable).
SELECT metric, sections,
       ROUND(100.0 * sections / (SELECT COUNT(*) FROM master_section), 2) AS pct_of_all_sections
FROM (
    SELECT 1 AS ord, 'has own enrollment'            AS metric, COUNT(*) FILTER (WHERE has_enrollment)          AS sections FROM master_section
    UNION ALL SELECT 2, 'missing enrollment',                   COUNT(*) FILTER (WHERE NOT has_enrollment)               FROM master_section
    UNION ALL SELECT 3, 'fillable: sibling enrollment',         COUNT(*) FILTER (WHERE fill_sibling_enrollment)          FROM master_section
    UNION ALL SELECT 4, 'fillable: own seats_taken',            COUNT(*) FILTER (WHERE fill_own_seats)                   FROM master_section
    UNION ALL SELECT 5, 'fillable: sibling seats_taken',        COUNT(*) FILTER (WHERE fill_sibling_seats)               FROM master_section
    UNION ALL SELECT 6, 'unfillable (no signal)',               COUNT(*) FILTER (WHERE NOT has_enrollment
                                                                   AND NOT fill_sibling_enrollment
                                                                   AND NOT fill_own_seats
                                                                   AND NOT fill_sibling_seats)                          FROM master_section
) ORDER BY ord
