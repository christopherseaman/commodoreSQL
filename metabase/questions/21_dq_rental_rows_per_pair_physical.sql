-- name: DQ — Physical Rental Observations per (Section × Item)
-- display: bar
-- description: All deduplicated physical-rental observations, counted per section/ISBN pair. Histogram across the latest pricing snapshot. X = observations per pair; Y = number of pairs. No catalog-derived inferred-required or canonical-Use filter is applied.

WITH counts_per_pair AS (
    SELECT section_id, isbn13,
        COUNT(*) FILTER (WHERE book_format = 'physical') AS rental_rows
    FROM pricing_historical
    WHERE book_option = 'rental'
    GROUP BY section_id, isbn13
)
SELECT rental_rows, COUNT(*) AS pairs
FROM counts_per_pair
WHERE rental_rows > 0
GROUP BY rental_rows
ORDER BY rental_rows
