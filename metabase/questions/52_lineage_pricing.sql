-- name: Lineage 3 — Raw Cost (BMG pricing)
-- display: table
-- description: All deduplicated latest-snapshot pricing observations for selected school. BMG pricing_historical retains one row per vendor price option after import deduplication. No inferred-required, canonical-Use, supply, or NoUse filter is applied; this is pricing lineage/DQ context. Shows all columns for this stage so every field is traceable. Optionally set the School (unit_id) filter. The LIMIT 200 is display-only.
SELECT *
FROM pricing_historical
WHERE 1 = 1
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, isbn13, book_option
LIMIT 200
