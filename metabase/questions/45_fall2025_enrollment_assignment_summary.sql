-- name: Fall 2025 — Enrollment Assignment Summary (source mix + raw vs assigned)
-- display: table
-- description: Companion to question 44, aggregating persisted enrollment fill (#32) over material-bearing Master Section rows. Per control x level x A/B set it reports fill-source counts, raw versus assigned enrollment, and the imputed share. The assignment ladder and medians still originate from the complete section_enrollment reference population; this card's denominator is the retained material-bearing scope. A/B membership uses required_count over canonical material_costs items.
SELECT
  control,
  CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
  CASE WHEN required_count > 0 THEN 'A: >=1 required' ELSE 'B: no required' END AS set,
  COUNT(*) AS sections,
  COUNT(*) FILTER (WHERE enrollment_source = 'own')            AS src_own,
  COUNT(*) FILTER (WHERE enrollment_source = 'own_seats')      AS src_own_seats,
  COUNT(*) FILTER (WHERE enrollment_source = 'sibling_enroll') AS src_sibling_enroll,
  COUNT(*) FILTER (WHERE enrollment_source = 'sibling_seats')  AS src_sibling_seats,
  COUNT(*) FILTER (WHERE enrollment_source = 'class_median')   AS src_class_median,
  COUNT(*) FILTER (WHERE enrollment_source = 'level_median')   AS src_level_median,
  SUM(enrollments)         AS enrollment_raw_sum,
  SUM(enrollment_assigned) AS enrollment_assigned_sum,
  ROUND(100.0 * SUM(enrollment_assigned - COALESCE(enrollments, 0)) / SUM(enrollment_assigned), 1) AS pct_imputed
FROM master_section
WHERE period_sortable = '2025-4'
  AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
  AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
GROUP BY control, lvl, set
ORDER BY control, lvl, set
