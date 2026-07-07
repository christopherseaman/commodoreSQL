-- name: DQ — Rental Row-Shape Distribution per (Section × Item)
-- display: table
-- description: Distinct (physical, digital, total) row-count shapes across (section, isbn) pairs in is_required_inferred=TRUE data, with how many pairs share each shape. Reveals the vendor offering pattern (e.g., 325 pairs share physical=2 / digital=13).

WITH counts_per_pair AS (
    SELECT section_id, isbn13,
        COUNT(*) FILTER (WHERE book_format = 'physical') AS physical,
        COUNT(*) FILTER (WHERE book_format = 'digital')  AS digital,
        COUNT(*) AS total
    FROM pricing_historical
    WHERE book_option = 'rental' AND is_required_inferred = TRUE
    GROUP BY section_id, isbn13
)
SELECT physical, digital, total, COUNT(*) AS pairs
FROM counts_per_pair
GROUP BY physical, digital, total
ORDER BY pairs DESC
LIMIT 30
