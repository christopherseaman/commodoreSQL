-- name: Fall 2025 — Course-material price by institution class (control x level x set)
-- display: table
-- description: Fall-2025 BMG-scope material-bearing sections; section-weighted price midpoints. Per-section course-material price summaries for material-bearing Fall-2025 Master Section rows in the BMG scope, broken out by institution control × level × A/B set. All medians are section-weighted, not enrollment-weighted; each section price_avg is its own (min+max)/2 midpoint. Set B has no required items, so required-price medians are NULL by construction; all-material price still covers its optional items. sections_priced_required counts retained sections with required_priced_count > 0. Treat small cells cautiously.
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
  ROUND(MEDIAN(required_price_avg), 2) AS "section_median_required_price",
  ROUND(MEDIAN((required_price_buy_min + required_price_buy_max) / 2.0), 2)
                                          AS "section_median_required_buy_price",
  ROUND(MEDIAN(all_price_avg), 2)      AS "section_median_all_material_price"
FROM scope
GROUP BY control, lvl, set
ORDER BY control, lvl, set
