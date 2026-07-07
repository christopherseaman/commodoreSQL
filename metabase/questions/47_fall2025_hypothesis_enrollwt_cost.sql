-- name: Fall 2025 — Hypothesis: Enrollment-Weighted Required Cost by Class
-- display: table
-- description: Tests whether 2-year (esp. public) students face higher required-material costs. Per institution class (control x 2yr/4yr), over Set A sections (>=1 required, course materials only — #36 supplies excluded) in the BMG scope with a priced required cost. sec_median_cost = section-weighted median of required_cost_avg ((min+max)/2, NOT a mean). enrollwt_mean = enrollment-weighted mean $/student using master_section.enrollment_assigned (#32): SUM(cost x enrollment)/SUM(enrollment). enrollwt_mean_own = the same over own-enrollment sections only (enrollment_source='own') — the imputation sensitivity check; close agreement with enrollwt_mean means the result is not an artifact of imputed enrollment. enrollwt_mean_wins99 winsorizes cost at the class p99 (outlier robustness). total_burden_musd = SUM(cost x enrollment) in $M. FINDING: Public 2yr students face ~$149/student vs ~$114 for Public 4yr (+31%), robust to imputation and outliers. Small/noisy for-profit and private-2yr cells reported but not headline. Cost gap is mostly course-mix, not same-item price (see the same-item price question).
WITH scope AS (
  SELECT *,
    CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl
  FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
    AND required_count > 0
    AND required_cost_avg IS NOT NULL
),
caps AS (
  SELECT control, lvl, quantile_cont(required_cost_avg, 0.99) AS cap99
  FROM scope GROUP BY control, lvl
)
SELECT
  s.control AS control,
  s.lvl AS level,
  COUNT(*) AS sections,
  ROUND(MEDIAN(s.required_cost_avg), 2) AS sec_median_cost,
  ROUND(SUM(s.required_cost_avg * s.enrollment_assigned) / SUM(s.enrollment_assigned), 2) AS enrollwt_mean,
  ROUND(SUM(s.required_cost_avg * s.enrollment_assigned) FILTER (WHERE s.enrollment_source = 'own')
        / NULLIF(SUM(s.enrollment_assigned) FILTER (WHERE s.enrollment_source = 'own'), 0), 2) AS enrollwt_mean_own,
  ROUND(SUM(LEAST(s.required_cost_avg, c.cap99) * s.enrollment_assigned) / SUM(s.enrollment_assigned), 2) AS enrollwt_mean_wins99,
  ROUND(100.0 * COUNT(*) FILTER (WHERE s.enrollment_source = 'own') / COUNT(*), 1) AS pct_own_enroll,
  ROUND(SUM(s.required_cost_avg * s.enrollment_assigned) / 1e6, 1) AS total_burden_musd
FROM scope s
JOIN caps c ON s.control = c.control AND s.lvl = c.lvl
GROUP BY s.control, s.lvl
ORDER BY enrollwt_mean DESC
