-- name: DQ — Rental Period Length Distribution (Digital, is_required_inferred=TRUE)
-- display: bar
-- description: Histogram of rental_days values for digital rentals in is_required_inferred=TRUE data. Physical rentals are excluded because they always have NULL rental_days (semester-implicit).

SELECT
    rental_days,
    COUNT(*) AS rows
FROM pricing_historical
WHERE book_option = 'rental'
  AND book_format = 'digital'
  AND is_required_inferred = TRUE
  AND rental_days IS NOT NULL
GROUP BY rental_days
ORDER BY rental_days
