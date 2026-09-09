-- name: DQ — Rental Row-Shape Distribution per (Section × Item)
-- display: table
-- description: All deduplicated rental section/ISBN pairs, by physical/digital observation-count shape. Distinct (physical, digital, total) latest-snapshot rental observation-count shapes across all (section, ISBN) pairs, with how many pairs share each shape. No catalog-derived inferred-required or canonical-Use filter is applied.

WITH counts_per_pair AS (
    SELECT section_id, isbn13,
        COUNT(*) FILTER (WHERE book_format = 'physical') AS physical,
        COUNT(*) FILTER (WHERE book_format = 'digital')  AS digital,
        COUNT(*) AS total
    FROM pricing_historical
    WHERE book_option = 'rental'
    GROUP BY section_id, isbn13
)
SELECT physical, digital, total, COUNT(*) AS pairs
FROM counts_per_pair
GROUP BY physical, digital, total
ORDER BY pairs DESC
LIMIT 30
