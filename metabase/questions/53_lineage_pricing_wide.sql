-- name: Lineage 4 — Pricing Wide (pivoted)
-- display: table
-- description: Pricing pivoted to one row per (section, ISBN): price_min/max (all options) + price_buy_min/max (owned). Sentinel prices nulled. Same school.
SELECT section_id, isbn13, title, price_min, price_max, price_buy_min, price_buy_max, format_count, required
FROM pricing_wide
WHERE 1=1
  [[ AND split_part(section_id, '::', 1) = {{unit_id}} ]]
ORDER BY section_id, isbn13
LIMIT 200
