-- name: Lineage 3 — Raw Cost (BMG pricing)
-- display: table
-- description: Original BMG pricing rows (one per price option). Same school.
SELECT section_id, isbn13, title, book_option, book_condition, book_format, rental_days, price
FROM pricing_historical
WHERE filter_include = TRUE
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, isbn13, book_option
LIMIT 200
