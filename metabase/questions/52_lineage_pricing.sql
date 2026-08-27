-- name: Lineage 3 — Raw Cost (BMG pricing)
-- display: table
-- description: Raw/all BMG pricing_historical rows (one per price option), restricted here to is_required_inferred = TRUE. No canonical #58 Use or supply/NoUse filtering is applied; this is pricing lineage/DQ context. Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter. The LIMIT 200 is display-only.
SELECT *
FROM pricing_historical
WHERE is_required_inferred = TRUE
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, isbn13, book_option
LIMIT 200
