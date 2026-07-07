-- name: DQ — Digital Rental Rows per (Section × Item) Histogram
-- display: bar
-- description: Histogram — for each (section, isbn) pair in is_required_inferred=TRUE data, count of digital rental rows. X = rows per pair; Y = number of pairs.

WITH counts_per_pair AS (
    SELECT section_id, isbn13,
        COUNT(*) FILTER (WHERE book_format = 'digital') AS rental_rows
    FROM pricing_historical
    WHERE book_option = 'rental' AND is_required_inferred = TRUE
    GROUP BY section_id, isbn13
)
SELECT rental_rows, COUNT(*) AS pairs
FROM counts_per_pair
WHERE rental_rows > 0
GROUP BY rental_rows
ORDER BY rental_rows
