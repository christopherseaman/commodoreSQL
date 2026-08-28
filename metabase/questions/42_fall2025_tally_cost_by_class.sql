-- name: Fall 2025 — Course-material cost by institution class (control x level x set)
-- display: table
-- description: Per-section course-material cost summaries for material-bearing Fall-2025 Master Section rows in the BMG scope, broken out by institution control × level × A/B set. All medians are section-weighted, not enrollment-weighted, and use the project (min+max)/2 summaries rather than arithmetic means. Set B is optional-only, so required-cost medians are NULL by construction; sections_priced_required counts retained sections with required_priced_count > 0. Treat small cells cautiously.
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
  COUNT(*) FILTER (WHERE required_priced_count > 0) AS sections_priced_required,
  ROUND(MEDIAN(required_cost_avg), 2)       AS "required_cost_median (min+max)/2",
  ROUND(MEDIAN(required_cost_owned_avg), 2) AS "required_cost_owned_median (min+max)/2",
  ROUND(MEDIAN(optional_cost_avg), 2)       AS "optional_cost_median (min+max)/2"
FROM scope
GROUP BY control, lvl, set
ORDER BY control, lvl, set
