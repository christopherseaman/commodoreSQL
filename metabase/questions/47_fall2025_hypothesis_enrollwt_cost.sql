-- name: Fall 2025 — Hypothesis: Enrollment-Weighted Required Price by Class
-- display: table
-- description: Fall-2025 BMG Set-A priced-required sections; enrollment-weighted section price midpoints. Tests whether 2-year (especially public) students face higher required-material prices. Each required_price_avg is the section's own (min+max)/2 midpoint; the reported median, enrollment-weighted means, winsorized mean, and burden are explicit analytical estimators across sections rather than price midpoints at the institution-class grain. The own-enrollment measure is an imputation sensitivity check. Historical finding labels are retained pending recomputation against the rebuilt schema.
WITH scope AS (
  SELECT *,
    CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl
  FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
    AND required_count > 0
    AND required_price_avg IS NOT NULL
),
caps AS (
  SELECT control, lvl, quantile_cont(required_price_avg, 0.99) AS cap99
  FROM scope GROUP BY control, lvl
)
SELECT
  s.control AS control,
  s.lvl AS level,
  COUNT(*) AS sections,
  ROUND(MEDIAN(s.required_price_avg), 2) AS section_median_required_price,
  ROUND(SUM(s.required_price_avg * s.enrollment_assigned) / SUM(s.enrollment_assigned), 2) AS enrollment_weighted_mean_required_price,
  ROUND(SUM(s.required_price_avg * s.enrollment_assigned) FILTER (WHERE s.enrollment_source = 'own')
        / NULLIF(SUM(s.enrollment_assigned) FILTER (WHERE s.enrollment_source = 'own'), 0), 2)
                                           AS own_enrollment_weighted_mean_required_price,
  ROUND(SUM(LEAST(s.required_price_avg, c.cap99) * s.enrollment_assigned) / SUM(s.enrollment_assigned), 2)
                                           AS winsorized_enrollment_weighted_mean_required_price,
  ROUND(100.0 * COUNT(*) FILTER (WHERE s.enrollment_source = 'own') / COUNT(*), 1) AS pct_own_enroll,
  ROUND(SUM(s.required_price_avg * s.enrollment_assigned) / 1e6, 1) AS total_burden_musd
FROM scope s
JOIN caps c ON s.control = c.control AND s.lvl = c.lvl
GROUP BY s.control, s.lvl
ORDER BY enrollment_weighted_mean_required_price DESC
