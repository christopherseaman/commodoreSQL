-- name: DQ — Canonical Required Material format_count Distribution
-- display: bar
-- description: Canonical inferred-required section/ISBN items with exact pricing matches. format_count distribution for canonical Course Materials Use items that are inferred-required and have an exact pricing match. One row is one master_material (period, section, ISBN) item; this is the canonical comparison to the deduplicated pricing-observation DQ cards, not a filtered pricing_historical population.

SELECT format_count, COUNT(*) AS canonical_required_material_rows
FROM master_material
WHERE is_required_inferred
  AND has_pricing_match
[[ AND {{period_sortable}} ]]
GROUP BY format_count
ORDER BY format_count
