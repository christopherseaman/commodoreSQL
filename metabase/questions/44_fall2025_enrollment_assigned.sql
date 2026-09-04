-- name: Fall 2025 — Section Enrollment Assignment (persisted fill + provenance)
-- display: table
-- description: Fall-2025 BMG-scope material-bearing sections; persisted full-spine enrollment assignments. Per-section enrollment fill for the material-bearing BMG grant scope (Fall 2025), reading persisted enrollment_assigned/enrollment_source values joined from the complete section_enrollment source (#32). Hierarchy: own -> own_seats -> sibling_enroll -> sibling_seats -> class_median -> level_median; medians are still computed over the full reference population, while this card displays only retained Master Section rows. Raw enrollments/seats_taken are never overwritten. A/B labels use required_count over canonical material_costs items. Metabase shows 2,000 rows; export for the full retained set.
SELECT
  section_id, course_id, unit_id, institution_name, state,
  control, level,
  CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
  sector,
  CASE WHEN required_count > 0 THEN 'A: >=1 required' ELSE 'B: no required' END AS set,
  department, course_title, course_subject,
  enrollments AS enrollment_raw,
  seats_taken,
  enrollment_assigned,
  enrollment_source
FROM master_section
WHERE period_sortable = '2025-4'
  AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
  AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
ORDER BY section_id
