-- name: Fall 2025 — Section & Enrollment Counts by Institution Class x Set
-- display: table
-- description: Headline size table for the BMG grant scope (Fall 2025, period_sortable=2025-4). One row per (control, lvl, set), where set A = sections with >=1 required material and B = no required material. Shows section counts, distinct institutions (unit_id), how many sections carry section-level enrollment (has_enrollment), the present-rate, the section-weighted enrollment_sum, and the enrollment_median over sections that have enrollment. Caveats: enrollment_sum is section-weighted (a total of section enrollments where present); enrollment_median is unweighted across sections and ignores NULL/missing enrollments (has_enrollment aligns exactly with enrollments IS NOT NULL), so both reflect only sections with data; pct_with_enrollment is the share of sections flagged has_enrollment; institutions_count is per-cell, so it will not sum across set A/B because an institution can appear in both. lvl maps level to 4yr/2yr.
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
