-- name: Fall 2025 — Sections with no price choice, by institution class (#46)
-- display: table
-- description: BMG grant Fall-2025 scope (period_sortable=2025-4, 4 BMG course levels, 6 real teaching sectors; 2,653,161 sections). For each in-scope section, required canonical Use materials (is_required_inferred and comprehensive_data.is_course_material_use) are joined to pricing_wide on (section_id, ISBN13) and restricted to those with a non-null price_min ('priced'). NO-PRICE-CHOICE definition (per 2026-07-09 refinement): a priced required material offers no price choice when pricing_wide.price_min = price_max — every acquisition option (buy/rent x new/used x format) costs the same, so there is no cheaper option to choose (regardless of format). A section has NO price choice if it has >=1 priced required material AND ALL of them have price_min = price_max. Sections with ZERO priced required materials are broken out separately as no_priced_required_material ('can't even see a price' — Set B sections plus Set A sections whose required item(s) never matched a priced pricing_wide row), since 'no visible price' and 'one fixed price' are different situations. Secondary comparison columns: alt_single_format (all required priced materials have format_count<=1 — the earlier format-based cut) and ia_only (all are inclusive-access, is_ia). pct_*_of_scope divides by all scope sections in the class cell; pct_*_of_priced divides by sections_with_priced_required. One row per (control, level 4yr/2yr) plus a TOTAL row. Small-n caution: Private for-profit 2yr. price_min/price_max/format_count/is_ia from pricing_wide (sentinel prices >=9999 nulled, #27); is_required_inferred/is_course_material_use from comprehensive_data.
WITH scope AS (
  SELECT section_id, control, level
  FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
),
required_priced AS (
  SELECT
    c.section_id,
    c.ISBN13,
    MAX(pw.format_count) AS format_count,
    BOOL_OR(pw.is_ia)    AS is_ia,
    MAX(pw.price_min)    AS price_min,
    MAX(pw.price_max)    AS price_max
  FROM comprehensive_data c
  JOIN scope s ON c.section_id = s.section_id
  LEFT JOIN pricing_wide pw
    ON c.section_id = pw.section_id AND c.ISBN13 = pw.isbn13
  WHERE c.is_required_inferred
    AND c.is_course_material_use
  GROUP BY c.section_id, c.ISBN13
),
priced_only AS (
  SELECT * FROM required_priced WHERE price_min IS NOT NULL
),
section_agg AS (
  SELECT
    section_id,
    COUNT(*) AS required_priced_count,
    COUNT(*) FILTER (WHERE price_min = price_max) AS single_price_count,
    COUNT(*) FILTER (WHERE format_count <= 1)     AS single_format_count,
    COUNT(*) FILTER (WHERE is_ia)                 AS ia_count
  FROM priced_only
  GROUP BY section_id
),
sections AS (
  SELECT
    s.section_id, s.control, s.level,
    COALESCE(sa.required_priced_count, 0) AS required_priced_count,
    sa.single_price_count,
    sa.single_format_count,
    sa.ia_count
  FROM scope s
  LEFT JOIN section_agg sa ON s.section_id = sa.section_id
)
SELECT
  COALESCE(control, 'TOTAL') AS control,
  COALESCE(CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' ELSE level END, 'TOTAL') AS lvl,
  COUNT(*) AS scope_sections,
  COUNT(*) FILTER (WHERE required_priced_count = 0) AS no_priced_required_material,
  ROUND(100.0 * COUNT(*) FILTER (WHERE required_priced_count = 0) / COUNT(*), 1) AS pct_no_priced_required_of_scope,
  COUNT(*) FILTER (WHERE required_priced_count > 0) AS sections_with_priced_required,
  COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_price_count = required_priced_count) AS no_price_choice,
  ROUND(100.0 * COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_price_count = required_priced_count) / COUNT(*), 1) AS pct_no_price_choice_of_scope,
  ROUND(100.0 * COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_price_count = required_priced_count) / NULLIF(COUNT(*) FILTER (WHERE required_priced_count > 0), 0), 1) AS pct_no_price_choice_of_priced,
  COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_format_count = required_priced_count) AS alt_single_format,
  COUNT(*) FILTER (WHERE required_priced_count > 0 AND ia_count = required_priced_count) AS alt_ia_only
FROM sections
GROUP BY GROUPING SETS ((control, lvl), ())
ORDER BY control NULLS LAST, lvl NULLS LAST
