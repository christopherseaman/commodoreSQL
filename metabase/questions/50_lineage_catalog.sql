-- name: Lineage 1 — Raw Catalog (BMG course materials)
-- display: table
-- description: Raw 2024+ catalog rows for selected school; no Use exclusions. Raw/all original BMG course-material rows dated 2024+ for the selected school. Shows ALL columns for this stage so every field is traceable; no canonical Use/NoUse, supply, ISBN, or Canada exclusion is applied. Set the School (unit_id) filter. The LIMIT 200 is display-only.
SELECT *
FROM course_catalog_20251215
WHERE period_date >= '2024-01-01'
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, ISBN13
LIMIT 200
