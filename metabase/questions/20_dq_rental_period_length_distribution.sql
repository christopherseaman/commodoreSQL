-- name: DQ — Digital Rental Period Length Distribution
-- display: bar
-- description: All deduplicated digital-rental observations with non-NULL rental_days. Histogram of non-NULL rental_days values in the latest pricing snapshot. No catalog-derived inferred-required or canonical-Use filter is applied; physical rentals are outside this card.

SELECT
    rental_days,
    COUNT(*) AS rows
FROM pricing_historical
WHERE book_option = 'rental'
  AND book_format = 'digital'
  AND rental_days IS NOT NULL
GROUP BY rental_days
ORDER BY rental_days
