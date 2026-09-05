-- name: Lineage 5 — Material Costs
-- display: table
-- description: Canonical material-cost rows for selected school; unmatched and unpriced items remain.
SELECT *
FROM material_costs
WHERE 1=1
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY period_sortable, section_id, isbn13
LIMIT 200
