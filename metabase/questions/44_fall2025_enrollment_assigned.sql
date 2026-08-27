-- name: Fall 2025 — Section Enrollment Assignment (persisted fill + provenance)
-- display: table
-- description: Per-section enrollment fill for the BMG grant scope (Fall 2025), one row per section, reading the PERSISTED model columns (#32) — enrollment_assigned and enrollment_source now live on master_section, computed in the pipeline from per-period medians over the reference population (the 4 BMG course levels x 6 real teaching sectors). Hierarchy: own (actual section enrollment) -> own_seats (own seats_taken < 9999) -> sibling_enroll (median enrollment of same-course sections this term) -> sibling_seats (median valid seats of those siblings) -> class_median (control x level) -> level_median (2yr/4yr). Assignment is exhaustive within scope (no NULLs). Raw enrollments/seats_taken are never overwritten. Values reproduce the reviewed analysis-layer assignment exactly (cards 133/134 method). Counts and A/B labels use canonical #58 Course Materials Use: required_count combines is_required_inferred with is_course_material_use. The complete valid section/enrollment spine remains the denominator. Metabase shows 2,000 rows; export for the full set.
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
