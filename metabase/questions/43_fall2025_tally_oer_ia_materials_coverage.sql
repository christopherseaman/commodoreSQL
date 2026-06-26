-- name: Fall 2025 — OER/IA Adoption & Material Coverage by Control x Level x Set
-- display: table
-- description: Per-section tally over master_section (BMG scope, Fall 2025 / period 2025-4) showing OER and Inclusive Access adoption, material load, and ISBN/format-type coverage, grouped by institution control x level (2yr/4yr) x A/B set (A = >=1 required item, B = no required item). Grain is one row per (control, lvl, set); rates are unweighted shares of sections (fractions, 3 dp) and the *_count_avg columns are unweighted mean items per section (2 dp), not enrollment-weighted. Caveats: Set B has no required item by definition (required_count_avg = 0, optional load only); has_isbn_rate = 1.0 for Set B is expected because the optional-only flagging path implies an ISBN. Small cells (Private for-profit 2yr A = 8, Private not-for-profit 2yr B = 8) make their rates statistically noisy.
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
