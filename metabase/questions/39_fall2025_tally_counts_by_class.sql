-- name: Fall 2025 — Section & Enrollment Counts by Institution Class x Set
-- display: table
-- description: Fall-2025 BMG-scope material-bearing sections, by control/level/required-item set. Headline size table for the material-bearing Fall-2025 BMG grant scope. One row per control × level × set, where Set A has at least one required canonical item and Set B is optional-only. Enrollment values originate from section_enrollment but the displayed denominator is retained Master Section rows. enrollment_sum and enrollment_median use only present raw enrollment; institutions_count is per cell and does not add across A/B.
WITH scope AS (
  SELECT * FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
)
SELECT
  control,
  CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
  CASE WHEN required_count > 0 THEN 'A: >=1 required' ELSE 'B: no required' END AS set,
  COUNT(*) AS sections_count,
  COUNT(DISTINCT unit_id) AS institutions_count,
  COUNT(*) FILTER (WHERE has_enrollment) AS sections_with_enrollment,
  ROUND(100.0 * COUNT(*) FILTER (WHERE has_enrollment) / COUNT(*), 1) AS pct_with_enrollment,
  SUM(enrollments) AS enrollment_sum,
  MEDIAN(enrollments) AS enrollment_median
FROM scope
GROUP BY control, lvl, set
ORDER BY control, lvl, set
