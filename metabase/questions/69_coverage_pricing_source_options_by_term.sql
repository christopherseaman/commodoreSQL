-- name: Coverage & Scope — Raw Pricing Options by Term
-- display: table
-- description: Current-snapshot source coverage at the BMG-owned pricing_historical observation grain, grouped by term × source option × condition × format with no canonical Use, required, or inferred-required filter. valid_price means price < 9999, so zero is valid; key counts use distinct raw section × ISBN pairs. This source denominator is deliberately different from canonical material_costs items.

SELECT
    period_sortable,
    COALESCE(NULLIF(TRIM(book_option), ''), '[NULL]') AS book_option,
    COALESCE(NULLIF(TRIM(book_condition), ''), '[NULL]') AS book_condition,
    COALESCE(NULLIF(TRIM(book_format), ''), '[NULL]') AS book_format,
    COUNT(*) AS pricing_observation_rows,
    COUNT(DISTINCT (section_id, isbn13)) AS section_isbn_key_count,
    COUNT(DISTINCT section_id) AS section_count,
    COUNT(DISTINCT isbn13) AS isbn_count,
    COUNT(DISTINCT unit_id) AS institution_count,
    COUNT(*) FILTER (WHERE price < 9999) AS valid_price_rows,
    COUNT(DISTINCT (section_id, isbn13)) FILTER (WHERE price < 9999)
        AS valid_price_section_isbn_key_count,
    COUNT(*) FILTER (WHERE price = 0) AS valid_zero_price_rows,
    COUNT(DISTINCT (section_id, isbn13)) FILTER (WHERE price = 0)
        AS valid_zero_price_section_isbn_key_count,
    COUNT(*) FILTER (WHERE book_option = 'rental') AS rental_rows,
    COUNT(DISTINCT (section_id, isbn13)) FILTER (WHERE book_option = 'rental')
        AS rental_section_isbn_key_count,
    COUNT(DISTINCT rental_days) FILTER (WHERE book_option = 'rental') AS rental_term_count,
    MIN(rental_days) FILTER (WHERE book_option = 'rental') AS rental_days_min,
    MAX(rental_days) FILTER (WHERE book_option = 'rental') AS rental_days_max
FROM pricing_historical
WHERE 1 = 1
[[ AND {{period_sortable}} ]]
GROUP BY
    period_sortable,
    COALESCE(NULLIF(TRIM(book_option), ''), '[NULL]'),
    COALESCE(NULLIF(TRIM(book_condition), ''), '[NULL]'),
    COALESCE(NULLIF(TRIM(book_format), ''), '[NULL]')
ORDER BY period_sortable, book_option, book_condition, book_format
