-- name: Fall 2025 — Section Enrollment Assignment (proposed fill + provenance)
-- display: table
-- description: ANALYSIS-LAYER enrollment fill for the BMG grant scope (Fall 2025), one row per section. NOT a model change — master_section is untouched; the eventual model column is tracked in #32. enrollment_assigned is the section's enrollment when present, else filled by a documented hierarchy and enrollment_source records which rung was used: own (actual section enrollment) -> own_seats (own seats_taken < 9999) -> sibling_enroll (median enrollment of same-course sections this term, within scope) -> sibling_seats (median valid seats of those siblings) -> class_median (median enrollment of the control x level class) -> level_median (median for 2yr/4yr; covers a class with no enrollment at all). Assignment is exhaustive (no NULLs). ~2.65M rows; ~31% of sections are imputed (own = has_enrollment). The hierarchy is the proposed default — adjustable; sibling/class medians recomputed WITHIN scope so fill counts can differ slightly from master_section's has_enrollment_* diagnostic flags (which span all periods/sectors). Metabase shows 2,000 rows; export for the full set.
WITH scope AS (
  SELECT * FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
),
course_agg AS (
  SELECT course_id,
    quantile_cont(enrollments, 0.5) AS ce_med,
    quantile_cont(CASE WHEN seats_taken < 9999 THEN seats_taken END, 0.5) AS cs_med
  FROM scope GROUP BY course_id
),
class_agg AS (
  SELECT control, level, quantile_cont(enrollments, 0.5) AS cl_med FROM scope GROUP BY control, level
),
level_agg AS (
  SELECT level, quantile_cont(enrollments, 0.5) AS lv_med FROM scope GROUP BY level
)
SELECT
  s.section_id, s.course_id, s.unit_id, s.institution_name, s.state,
  s.control, s.level,
  CASE s.level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
  s.sector,
  CASE WHEN s.required_count > 0 THEN 'A: >=1 required' ELSE 'B: no required' END AS set,
  s.department, s.course_title, s.course_subject,
  s.enrollments AS enrollment_raw,
  s.seats_taken,
  ROUND(COALESCE(s.enrollments, CASE WHEN s.seats_taken < 9999 THEN s.seats_taken END, ca.ce_med, ca.cs_med, cl.cl_med, lv.lv_med))::INT AS enrollment_assigned,
  CASE
    WHEN s.enrollments IS NOT NULL          THEN 'own'
    WHEN s.seats_taken < 9999               THEN 'own_seats'
    WHEN ca.ce_med IS NOT NULL              THEN 'sibling_enroll'
    WHEN ca.cs_med IS NOT NULL              THEN 'sibling_seats'
    WHEN cl.cl_med IS NOT NULL              THEN 'class_median'
    WHEN lv.lv_med IS NOT NULL              THEN 'level_median'
    ELSE 'none'
  END AS enrollment_source
FROM scope s
LEFT JOIN course_agg ca ON s.course_id = ca.course_id
LEFT JOIN class_agg  cl ON s.control = cl.control AND s.level = cl.level
LEFT JOIN level_agg  lv ON s.level = lv.level
ORDER BY s.section_id
