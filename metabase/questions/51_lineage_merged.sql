-- name: Lineage 2 — Merged (catalog × IPEDS × OER/IA)
-- display: table
-- description: Merged record — catalog + IPEDS + OER/IA + filter_include + coverage flags. Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.
SELECT *
FROM comprehensive_data
WHERE period_date >= '2024-01-01'
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, ISBN13
LIMIT 200
