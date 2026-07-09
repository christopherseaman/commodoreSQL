-- name: Fall 2025 — Sections with no price choice, by institution class (#46)
-- display: table
-- description: PROVISIONAL definition, easy to swap. BMG grant Fall-2025 scope (period_sortable=2025-4, 4 BMG course levels, 6 real teaching sectors; 2,653,161 sections total). For each in-scope section, required (is_required_inferred) non-supply (NOT is_supply) materials are joined to pricing_wide on (section_id, ISBN13) and restricted to those with a non-null price_min ('priced'). DEFAULT no-price-choice definition: a section has NO price choice if it has >=1 priced required material AND every one of them has pricing_wide.format_count<=1 (no buy-vs-rent, no new-vs-used, no multi-format). Sections with ZERO priced required materials are NOT counted as 'no choice' under the default -- they are broken out separately as no_priced_required_material (includes Set B sections with no required item at all, plus Set A sections whose required item(s) never matched a priced pricing_wide row) because 'no visible price' and 'exactly one priced option' are different situations. Two alternative/looser-or-stricter variants are reported alongside the default for sensitivity: no_choice_single_channel (has_buy XOR has_rent per item -- looser, ignores new/used and format variation) and ia_only_sections (every priced required item is inclusive-access, is_ia -- narrower/stricter). All three variant counts are measured against sections_with_priced_required (the only population where choice is even measurable); pct_..._of_scope divides by all scope sections in the class cell, pct_..._of_priced divides by sections_with_priced_required in that cell. Grain: one row per (control, level 4yr/2yr) plus a TOTAL row. Small-n caution: Private for-profit 2yr n=8. price_min/format_count/has_buy/has_rent/is_ia are sourced from pricing_wide (sentinel prices >=9999 already nulled, #27); is_required_inferred/is_supply from comprehensive_data.
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
    BOOL_OR(pw.has_buy)  AS has_buy,
    BOOL_OR(pw.has_rent) AS has_rent,
    BOOL_OR(pw.is_ia)    AS is_ia,
    MAX(pw.price_min)    AS price_min
  FROM comprehensive_data c
  JOIN scope s ON c.section_id = s.section_id
  LEFT JOIN pricing_wide pw
    ON c.section_id = pw.section_id AND c.ISBN13 = pw.isbn13
  WHERE c.ISBN13 IS NOT NULL
    AND c.is_required_inferred
    AND NOT c.is_supply
  GROUP BY c.section_id, c.ISBN13
),
priced_only AS (
  SELECT * FROM required_priced WHERE price_min IS NOT NULL
),
section_agg AS (
  SELECT
    section_id,
    COUNT(*) AS required_priced_count,
    COUNT(*) FILTER (WHERE format_count <= 1) AS single_option_count,
    COUNT(*) FILTER (WHERE (has_buy AND NOT has_rent) OR (has_rent AND NOT has_buy)) AS single_channel_count,
    COUNT(*) FILTER (WHERE is_ia) AS ia_count
  FROM priced_only
  GROUP BY section_id
),
sections AS (
  SELECT
    s.section_id, s.control, s.level,
    COALESCE(sa.required_priced_count, 0) AS required_priced_count,
    sa.single_option_count,
    sa.single_channel_count,
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
  COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_option_count = required_priced_count) AS no_choice_default,
  ROUND(100.0 * COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_option_count = required_priced_count) / COUNT(*), 1) AS pct_no_choice_default_of_scope,
  ROUND(100.0 * COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_option_count = required_priced_count) / NULLIF(COUNT(*) FILTER (WHERE required_priced_count > 0), 0), 1) AS pct_no_choice_default_of_priced,
  COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_channel_count = required_priced_count) AS no_choice_single_channel,
  ROUND(100.0 * COUNT(*) FILTER (WHERE required_priced_count > 0 AND single_channel_count = required_priced_count) / NULLIF(COUNT(*) FILTER (WHERE required_priced_count > 0), 0), 1) AS pct_no_choice_single_channel_of_priced,
  COUNT(*) FILTER (WHERE required_priced_count > 0 AND ia_count = required_priced_count) AS ia_only_sections,
  ROUND(100.0 * COUNT(*) FILTER (WHERE required_priced_count > 0 AND ia_count = required_priced_count) / NULLIF(COUNT(*) FILTER (WHERE required_priced_count > 0), 0), 1) AS pct_ia_only_of_priced
FROM sections
GROUP BY GROUPING SETS ((control, lvl), ())
ORDER BY control NULLS LAST, lvl NULLS LAST
