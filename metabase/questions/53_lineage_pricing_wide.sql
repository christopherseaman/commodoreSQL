-- name: Lineage 4 — Pricing Wide (pivoted)
-- display: table
-- description: Pricing-wide section/ISBN pairs for selected school. Pricing pivoted to one row per (section, ISBN): 18 price cells + has_buy/has_rent + ranges. Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.
SELECT *
FROM pricing_wide
WHERE 1=1
  [[ AND split_part(section_id, '::', 1) = {{unit_id}} ]]
ORDER BY section_id, isbn13
LIMIT 200
