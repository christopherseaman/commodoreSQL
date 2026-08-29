-- name: DQ — Canonical Required Material format_count Distribution
-- display: bar
-- description: format_count distribution for canonical Course Materials Use items that are inferred-required and have an exact pricing match. One row is one material_costs (period, section, ISBN) item; this is the canonical comparison to the raw pricing DQ cards, not a filtered raw-pricing population.

SELECT format_count, COUNT(*) AS canonical_required_material_rows
FROM material_costs
WHERE is_required_inferred
  AND has_pricing_match
GROUP BY format_count
ORDER BY format_count
