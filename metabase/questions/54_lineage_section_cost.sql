-- name: Lineage 5 — Section Cost
-- display: table
-- description: Section-cost rows for selected school; all-options and buy-only. Cost rolled to one row per section (all-options + owned). Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.
SELECT *
FROM section_cost
WHERE 1=1
  [[ AND split_part(section_id, '::', 1) = {{unit_id}} ]]
ORDER BY section_id
LIMIT 200
