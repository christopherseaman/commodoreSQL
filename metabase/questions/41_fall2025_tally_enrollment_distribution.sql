-- name: Fall 2025 — Section Enrollment Distribution by Control x Level (present only)
-- display: table
-- description: Distribution of per-section enrollment for Fall 2025 (period 2025-4), restricted to sections within the BMG grant scope (issue #35) that have a non-NULL enrollment value, grouped by institution control x level (2yr/4yr). Grain is one row per control x lvl class; sections_n_present counts sections with enrollment present (NULL excluded by COUNT/quantile/AVG). enrollment_mean is the arithmetic AVG (real central tendency), distinct from any *_cost_avg legacy (min+max)/2; percentiles use quantile_cont. Caveats: distribution is strongly right-skewed (mean > median in every class; p90 is 36-50 while max reaches 485-550, an extreme tail), and a per-class min of 0 indicates present-but-zero-enrollment sections that are not the same as missing enrollment. The two Private rows (for-profit 4yr n=2538, not-for-profit 2yr n=300) are tiny and statistically thin compared to Public and Private not-for-profit 4yr.
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
