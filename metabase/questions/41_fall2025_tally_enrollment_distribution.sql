-- name: Fall 2025 — Section Enrollment Distribution by Control x Level (present only)
-- display: table
-- description: Distribution of present raw per-section enrollment among material-bearing Fall-2025 Master Section rows in the BMG grant scope, grouped by institution control × level. sections_n_present excludes NULL enrollment; enrollment_mean is the arithmetic mean and percentiles use quantile_cont. Enrollment values originate from section_enrollment, but no-adoption and NoUse-only sections are outside this card's denominator. Small class cells and the right-skewed tail should be interpreted cautiously.
WITH scope AS (
  SELECT * FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
)
SELECT
  control,
  CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
  COUNT(enrollments) AS sections_n_present,
  MIN(enrollments) AS enrollment_min,
  CAST(quantile_cont(enrollments, 0.10) AS INT) AS enrollment_p10,
  CAST(quantile_cont(enrollments, 0.25) AS INT) AS enrollment_p25,
  CAST(quantile_cont(enrollments, 0.50) AS INT) AS enrollment_median,
  ROUND(AVG(enrollments), 1) AS enrollment_mean,
  CAST(quantile_cont(enrollments, 0.75) AS INT) AS enrollment_p75,
  CAST(quantile_cont(enrollments, 0.90) AS INT) AS enrollment_p90,
  MAX(enrollments) AS enrollment_max,
  ROUND(STDDEV_SAMP(enrollments), 1) AS enrollment_stddev
FROM scope
WHERE enrollments IS NOT NULL
GROUP BY control, lvl
ORDER BY control, lvl
