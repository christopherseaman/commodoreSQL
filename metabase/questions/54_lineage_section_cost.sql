-- name: Lineage 5 — Section Cost
-- display: table
-- description: Cost rolled to one row per section — sum over distinct required/non-required materials (all-options + owned/buy-only). Same school.
SELECT section_id, required_cost_total_min, required_cost_total_max, required_cost_owned_min, required_cost_owned_max, optional_cost_total_min, optional_cost_total_max, required_priced_count
FROM section_cost
WHERE 1=1
  [[ AND split_part(section_id, '::', 1) = {{unit_id}} ]]
ORDER BY section_id
LIMIT 200
