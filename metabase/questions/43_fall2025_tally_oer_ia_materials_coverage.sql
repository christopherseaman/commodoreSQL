-- name: Fall 2025 — OER/IA Adoption & Material Coverage by Control x Level x Set
-- display: table
-- description: Fall-2025 BMG-scope material-bearing sections; unweighted section shares/item counts. Per-section tally over material-bearing Master Section rows in the Fall-2025 BMG scope, showing OER/IA adoption, material load, and ISBN/FormatType coverage by institution control × level × A/B set. Rates are unweighted retained-section shares and *_count_avg columns are unweighted item counts per retained section. Set B is optional-only by definition; all rows carry at least one canonical master_material item. Treat small institution-class cells as statistically noisy.
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
  ROUND(AVG(CASE WHEN is_oer THEN 1.0 ELSE 0.0 END), 3) AS oer_rate,
  ROUND(AVG(CASE WHEN is_ia THEN 1.0 ELSE 0.0 END), 3) AS ia_rate,
  ROUND(AVG(material_count), 2) AS material_count_avg,
  ROUND(AVG(required_count), 2) AS required_count_avg,
  ROUND(AVG(optional_count), 2) AS optional_count_avg,
  ROUND(AVG(CASE WHEN has_isbn THEN 1.0 ELSE 0.0 END), 3) AS has_isbn_rate,
  ROUND(AVG(CASE WHEN has_formattype THEN 1.0 ELSE 0.0 END), 3) AS has_formattype_rate
FROM scope
GROUP BY control, lvl, set
ORDER BY control, lvl, set
