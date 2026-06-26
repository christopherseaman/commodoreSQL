-- name: Fall 2025 — Enrollment Assignment Summary (source mix + raw vs assigned)
-- display: table
-- description: Decision artifact for the proposed enrollment fill (companion to question 44). Per control x level x A/B set: section counts by fill source (own, own_seats, sibling_enroll, sibling_seats, class_median, level_median), the raw enrollment sum (present only) vs the assigned sum (filled), and pct_imputed = share of the assigned total that comes from imputation. Shows how much each rung contributes and how totals shift once missing enrollment is filled. Overall: raw 52.8M -> assigned 74.0M, ~28.6% imputed; ~22% of sections take the weakest rung (class_median) because sibling/seats signals reach only ~9%. Hierarchy is the proposed default (own -> own_seats -> sibling_enroll -> sibling_seats -> class_median -> level_median); model column tracked in #32.
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
),
assigned AS (
  SELECT
    s.control,
    CASE s.level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
    CASE WHEN s.required_count > 0 THEN 'A: >=1 required' ELSE 'B: no required' END AS set,
    s.enrollments,
    ROUND(COALESCE(s.enrollments, CASE WHEN s.seats_taken < 9999 THEN s.seats_taken END, ca.ce_med, ca.cs_med, cl.cl_med, lv.lv_med))::INT AS enr_assigned,
    CASE
      WHEN s.enrollments IS NOT NULL THEN 'own'
      WHEN s.seats_taken < 9999      THEN 'own_seats'
      WHEN ca.ce_med IS NOT NULL     THEN 'sibling_enroll'
      WHEN ca.cs_med IS NOT NULL     THEN 'sibling_seats'
      WHEN cl.cl_med IS NOT NULL     THEN 'class_median'
      WHEN lv.lv_med IS NOT NULL     THEN 'level_median'
      ELSE 'none'
    END AS src
  FROM scope s
  LEFT JOIN course_agg ca ON s.course_id = ca.course_id
  LEFT JOIN class_agg  cl ON s.control = cl.control AND s.level = cl.level
  LEFT JOIN level_agg  lv ON s.level = lv.level
)
SELECT
  control, lvl, set,
  COUNT(*) AS sections,
  COUNT(*) FILTER (WHERE src = 'own')            AS src_own,
  COUNT(*) FILTER (WHERE src = 'own_seats')      AS src_own_seats,
  COUNT(*) FILTER (WHERE src = 'sibling_enroll') AS src_sibling_enroll,
  COUNT(*) FILTER (WHERE src = 'sibling_seats')  AS src_sibling_seats,
  COUNT(*) FILTER (WHERE src = 'class_median')   AS src_class_median,
  COUNT(*) FILTER (WHERE src = 'level_median')   AS src_level_median,
  SUM(enrollments)  AS enrollment_raw_sum,
  SUM(enr_assigned) AS enrollment_assigned_sum,
  ROUND(100.0 * SUM(enr_assigned - COALESCE(enrollments, 0)) / SUM(enr_assigned), 1) AS pct_imputed
FROM assigned
GROUP BY control, lvl, set
ORDER BY control, lvl, set
