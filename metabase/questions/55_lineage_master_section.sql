-- name: Lineage 6 — Master Section (wide record)
-- display: table
-- description: The wide section record — counts, OER/IA, coverage + enrollment fill-potential flags, cost. Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.
SELECT *
FROM master_section
WHERE 1=1
  [[ AND split_part(section_id, '::', 1) = {{unit_id}} ]]
ORDER BY section_id
LIMIT 200
