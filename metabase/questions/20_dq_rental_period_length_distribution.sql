-- name: DQ — Rental Period Length Distribution (Digital, filter_include=TRUE)
-- display: bar
-- description: Histogram of rental_days values for digital rentals in filter_include=TRUE data. Physical rentals are excluded because they always have NULL rental_days (semester-implicit).

SELECT
    rental_days,
    COUNT(*) AS rows
FROM pricing_historical
WHERE book_option = 'rental'
  AND book_format = 'digital'
  AND filter_include = TRUE
  AND rental_days IS NOT NULL
GROUP BY rental_days
ORDER BY rental_days
