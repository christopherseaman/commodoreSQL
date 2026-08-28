-- name: Fall 2025 — Sections with no price choice, by institution class (#46)
-- display: table
-- description: BMG grant Fall-2025 material-bearing scope (period_sortable=2025-4; 4 BMG course levels × 6 teaching sectors). Required canonical items come from material_costs and are priced when price_min is non-null. A priced required item offers no price choice when price_min = price_max; a section has no price choice when it has at least one priced required item and all meet that condition. no_priced_required_material includes optional-only Set B plus required-bearing sections with no visible required price. pct_*_of_scope divides by retained material-bearing Master Section rows; price/format/IA fields come from material_costs and sentinel prices remain nulled upstream.
WITH scope AS (
  SELECT section_id, control, level
  FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
),
priced_only AS (
  SELECT
    m.section_id,
    m.isbn13,
    m.format_count,
    m.is_ia,
    m.price_min,
    m.price_max
  FROM material_costs m
  JOIN scope s ON m.section_id = s.section_id
  WHERE m.period_sortable = '2025-4'
    AND m.is_required_inferred
    AND m.price_min IS NOT NULL
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
