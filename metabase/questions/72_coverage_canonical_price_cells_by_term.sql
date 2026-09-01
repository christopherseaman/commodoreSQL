-- name: Coverage & Scope — Canonical Price Cells by Term
-- display: table
-- description: Current-snapshot price-cell coverage from canonical master_isbn term × ISBN rows. The 18 option × condition × format section-count cells are summed once per term and then normalized; canonical_section_item_occurrences = SUM(section_id_count) is the denominator, isbn_count is the number of canonical ISBN rows, and price_cell_occurrence_count can overlap across cells for the same section × ISBN. This is a canonical retained Use population, not raw pricing_historical observations.

WITH term_totals AS (
    SELECT
        period_sortable,
        COUNT(*) AS isbn_count,
        SUM(section_id_count) AS canonical_section_item_occurrences,
        SUM(price_buy_new_physical_count) AS price_buy_new_physical_count,
        SUM(price_buy_new_digital_count) AS price_buy_new_digital_count,
        SUM(price_buy_new_na_count) AS price_buy_new_na_count,
        SUM(price_buy_used_physical_count) AS price_buy_used_physical_count,
        SUM(price_buy_used_digital_count) AS price_buy_used_digital_count,
        SUM(price_buy_used_na_count) AS price_buy_used_na_count,
        SUM(price_buy_na_physical_count) AS price_buy_na_physical_count,
        SUM(price_buy_na_digital_count) AS price_buy_na_digital_count,
        SUM(price_buy_na_na_count) AS price_buy_na_na_count,
        SUM(price_rental_new_physical_count) AS price_rental_new_physical_count,
        SUM(price_rental_new_digital_count) AS price_rental_new_digital_count,
        SUM(price_rental_new_na_count) AS price_rental_new_na_count,
        SUM(price_rental_used_physical_count) AS price_rental_used_physical_count,
        SUM(price_rental_used_digital_count) AS price_rental_used_digital_count,
        SUM(price_rental_used_na_count) AS price_rental_used_na_count,
        SUM(price_rental_na_physical_count) AS price_rental_na_physical_count,
        SUM(price_rental_na_digital_count) AS price_rental_na_digital_count,
        SUM(price_rental_na_na_count) AS price_rental_na_na_count
    FROM master_isbn
    WHERE 1 = 1
    [[ AND {{period_sortable}} ]]
    GROUP BY period_sortable
), normalized AS (
    UNPIVOT term_totals
    ON COLUMNS(* EXCLUDE (period_sortable, isbn_count, canonical_section_item_occurrences))
    INTO NAME price_cell VALUE price_cell_occurrence_count
)
SELECT
    period_sortable,
    CASE SPLIT_PART(price_cell, '_', 2)
        WHEN 'buy' THEN 'buy'
        WHEN 'rental' THEN 'rental'
    END AS book_option,
    CASE SPLIT_PART(price_cell, '_', 3)
        WHEN 'na' THEN '[NULL]'
        ELSE SPLIT_PART(price_cell, '_', 3)
    END AS book_condition,
    CASE SPLIT_PART(price_cell, '_', 4)
        WHEN 'na' THEN '[NULL]'
        ELSE SPLIT_PART(price_cell, '_', 4)
    END AS book_format,
    isbn_count,
    canonical_section_item_occurrences,
    price_cell_occurrence_count,
    ROUND(100.0 * price_cell_occurrence_count
        / NULLIF(canonical_section_item_occurrences, 0), 2)
        AS pct_of_canonical_section_item_occurrences
FROM normalized
ORDER BY period_sortable, book_option, book_condition, book_format
