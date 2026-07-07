-- name: Lineage 3 — Raw Cost (BMG pricing)
-- display: table
-- description: Original BMG pricing rows (one per price option). Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.
SELECT *
FROM pricing_historical
WHERE is_required_inferred = TRUE
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, isbn13, book_option
LIMIT 200
