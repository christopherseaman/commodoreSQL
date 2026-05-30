-- name: DQ — Physical Rental Rows per (Section × Item) Histogram
-- display: bar
-- description: Histogram — for each (section, isbn) pair in filter_include=TRUE data, count of physical rental rows. X = rows per pair; Y = number of pairs.

WITH counts_per_pair AS (
    SELECT section_id, isbn13,
        COUNT(*) FILTER (WHERE book_format = 'physical') AS rental_rows
    FROM pricing_historical
    WHERE book_option = 'rental' AND filter_include = TRUE
    GROUP BY section_id, isbn13
)
SELECT rental_rows, COUNT(*) AS pairs
FROM counts_per_pair
WHERE rental_rows > 0
GROUP BY rental_rows
ORDER BY rental_rows
