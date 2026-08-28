-- name: Fall 2025 — Enrollment Missingness & Fill-Potential by Control × Level × Set
-- display: table
-- description: Per-section tally over the material-bearing Fall-2025 Master Section BMG scope, showing enrollment coverage and fill-potential by institution control × level × A/B set (A = >=1 required item, B = optional-only). Enrollment signals originate from the complete section_enrollment population, but this card's section denominator is narrowed to retained material-bearing sections. The three fill signals overlap, so missing_w_* do not sum to missing; unfillable is missing minus their union.
WITH scope AS (
  SELECT * FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
),
base AS (
  SELECT
    control,
    CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
    CASE WHEN required_count > 0 THEN 'A: >=1 required' ELSE 'B: no required' END AS set,
    has_enrollment,
    has_enrollment_sibling,
    has_enrollment_own_seats,
    has_enrollment_sibling_seats
  FROM scope
)
SELECT
  control,
  lvl,
  set,
  COUNT(*) AS sections_count,
  COUNT(*) FILTER (WHERE has_enrollment) AS has_enrollment,
  COUNT(*) FILTER (WHERE NOT has_enrollment) AS missing,
  COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_sibling) AS missing_w_sibling_enroll,
  COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_own_seats) AS missing_w_own_seats,
  COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_sibling_seats) AS missing_w_sibling_seats,
  COUNT(*) FILTER (WHERE NOT has_enrollment AND NOT has_enrollment_sibling AND NOT has_enrollment_own_seats AND NOT has_enrollment_sibling_seats) AS unfillable,
  ROUND(100.0 * COUNT(*) FILTER (WHERE NOT has_enrollment) / COUNT(*), 1) AS pct_missing,
  ROUND(100.0 * COUNT(*) FILTER (WHERE NOT has_enrollment AND NOT has_enrollment_sibling AND NOT has_enrollment_own_seats AND NOT has_enrollment_sibling_seats) / COUNT(*), 1) AS pct_unfillable
FROM base
GROUP BY control, lvl, set
ORDER BY control, lvl, set
