-- Wide pricing analysis view: one row per (section_id, isbn13)
-- 18 price columns (option × condition × format) plus required flag, OER/IA classification,
-- and fact aggregations: format_count, price_min/max/avg, rental_days_min/max.
-- Filtered using catalog section_book_status (has_required) and period >= 2024.
--
-- Note on rentals: `book_option = 'rental'` is the only case with multiple price points per
-- (option × condition × format), since `rental_days` (~95 distinct values) varies by term.
-- The wide pivot collapses these via MAX(price); rental_days_min/max preserve the term range.
--
-- Naming standard for fact aggregations: <dimension>_<aggfunc>
--   format_count, price_min, price_max, price_avg, rental_days_min, rental_days_max
-- See CLAUDE.md for full conventions.

${CONFIG}

DROP VIEW IF EXISTS pricing_wide;

CREATE VIEW pricing_wide AS
SELECT
    section_id,
    isbn13,
    BOOL_OR(required) AS required,
    -- is_oer / is_ia stored on pricing_historical via 2b_pricing_oer_ia.sql
    -- (BOOL_OR taken as definitive; see that file for DQ check vs BOOL_AND)
    BOOL_OR(is_oer) AS is_oer,
    BOOL_OR(is_ia)  AS is_ia,
    -- Section/ISBN-level descriptive
    MAX(institute) AS institute,
    MAX(bookstore_url) AS bookstore_url,
    MAX(title) AS title,
    MAX(author) AS author,
    MAX(publisher) AS publisher,
    MAX(edition) AS edition,
    -- Buy x New
    MAX(CASE WHEN book_option = 'buy' AND book_condition = 'new' AND book_format = 'physical' THEN price END) AS price_buy_new_physical,
    MAX(CASE WHEN book_option = 'buy' AND book_condition = 'new' AND book_format = 'digital'  THEN price END) AS price_buy_new_digital,
    MAX(CASE WHEN book_option = 'buy' AND book_condition = 'new' AND book_format IS NULL      THEN price END) AS price_buy_new_na,
    -- Buy x Used
    MAX(CASE WHEN book_option = 'buy' AND book_condition = 'used' AND book_format = 'physical' THEN price END) AS price_buy_used_physical,
    MAX(CASE WHEN book_option = 'buy' AND book_condition = 'used' AND book_format = 'digital'  THEN price END) AS price_buy_used_digital,
    MAX(CASE WHEN book_option = 'buy' AND book_condition = 'used' AND book_format IS NULL      THEN price END) AS price_buy_used_na,
    -- Buy x N/A condition
    MAX(CASE WHEN book_option = 'buy' AND book_condition IS NULL AND book_format = 'physical' THEN price END) AS price_buy_na_physical,
    MAX(CASE WHEN book_option = 'buy' AND book_condition IS NULL AND book_format = 'digital'  THEN price END) AS price_buy_na_digital,
    MAX(CASE WHEN book_option = 'buy' AND book_condition IS NULL AND book_format IS NULL      THEN price END) AS price_buy_na_na,
    -- Rental x New
    MAX(CASE WHEN book_option = 'rental' AND book_condition = 'new' AND book_format = 'physical' THEN price END) AS price_rental_new_physical,
    MAX(CASE WHEN book_option = 'rental' AND book_condition = 'new' AND book_format = 'digital'  THEN price END) AS price_rental_new_digital,
    MAX(CASE WHEN book_option = 'rental' AND book_condition = 'new' AND book_format IS NULL      THEN price END) AS price_rental_new_na,
    -- Rental x Used
    MAX(CASE WHEN book_option = 'rental' AND book_condition = 'used' AND book_format = 'physical' THEN price END) AS price_rental_used_physical,
    MAX(CASE WHEN book_option = 'rental' AND book_condition = 'used' AND book_format = 'digital'  THEN price END) AS price_rental_used_digital,
    MAX(CASE WHEN book_option = 'rental' AND book_condition = 'used' AND book_format IS NULL      THEN price END) AS price_rental_used_na,
    -- Rental x N/A condition
    MAX(CASE WHEN book_option = 'rental' AND book_condition IS NULL AND book_format = 'physical' THEN price END) AS price_rental_na_physical,
    MAX(CASE WHEN book_option = 'rental' AND book_condition IS NULL AND book_format = 'digital'  THEN price END) AS price_rental_na_digital,
    MAX(CASE WHEN book_option = 'rental' AND book_condition IS NULL AND book_format IS NULL      THEN price END) AS price_rental_na_na,
    -- Fact aggregations: <dimension>_<aggfunc>
    -- format_count = distinct purchase formats with a pivot column (buy/rental only); equals non-null pivot cells, max 18.
    -- Rows with book_option NULL (~5% of data) have no pivot column and are excluded.
    COUNT(DISTINCT (book_option, book_condition, book_format)) FILTER (WHERE book_option IN ('buy', 'rental')) AS format_count,
    -- price_min/max/avg span ALL variations including rental_days, so they capture full price spread.
    MIN(price) AS price_min,
    MAX(price) AS price_max,
    -- LEGACY definition: price_avg = (min + max) / 2 — NOT the arithmetic mean. See CLAUDE.md.
    (MIN(price) + MAX(price)) / 2.0 AS price_avg,
    MIN(rental_days) FILTER (WHERE book_option = 'rental') AS rental_days_min,
    MAX(rental_days) FILTER (WHERE book_option = 'rental') AS rental_days_max
FROM pricing_historical
WHERE filter_include = TRUE
GROUP BY section_id, isbn13;

-- Summary statistics
SELECT 'Wide pricing rows' AS metric, COUNT(*)::VARCHAR AS value FROM pricing_wide
UNION ALL
SELECT 'Unique section_ids', COUNT(DISTINCT section_id)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'Unique ISBNs', COUNT(DISTINCT isbn13)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'Required rows', COUNT(*)::VARCHAR FROM pricing_wide WHERE required = TRUE
UNION ALL
SELECT 'Avg format_count', ROUND(AVG(format_count), 2)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'price_min range', MIN(price_min)::VARCHAR || ' - ' || MAX(price_min)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'price_max range', MIN(price_max)::VARCHAR || ' - ' || MAX(price_max)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'rental_days_min range', MIN(rental_days_min)::VARCHAR || ' - ' || MAX(rental_days_min)::VARCHAR FROM pricing_wide WHERE rental_days_min IS NOT NULL
UNION ALL
SELECT 'rental_days_max range', MIN(rental_days_max)::VARCHAR || ' - ' || MAX(rental_days_max)::VARCHAR FROM pricing_wide WHERE rental_days_max IS NOT NULL;

-- DQ check: SUM(format_count) in wide should equal the count of distinct
-- (section_id, isbn13, book_option, book_condition, book_format) keys in tall (filtered to buy/rental).
-- Mismatch indicates the pivot lost data.
WITH tall AS (
    SELECT COUNT(DISTINCT (section_id, isbn13, book_option, book_condition, book_format)) AS tall_distinct_keys
    FROM pricing_historical
    WHERE filter_include = TRUE AND book_option IN ('buy', 'rental')
),
wide AS (
    SELECT SUM(format_count) AS wide_format_sum FROM pricing_wide
)
SELECT
    'Tall vs wide DQ' AS metric,
    tall.tall_distinct_keys,
    wide.wide_format_sum,
    (tall.tall_distinct_keys - wide.wide_format_sum) AS difference
FROM tall, wide;

-- DQ: format_count distribution — how rich is the pivot per (section, isbn)?
SELECT
    'format_count distribution' AS check_name,
    format_count,
    COUNT(*) AS pricing_wide_rows
FROM pricing_wide
GROUP BY format_count
ORDER BY format_count
LIMIT 10;

-- DQ: cross buy/rental coverage — how often do bookstores offer both?
WITH classified AS (
    SELECT
        (price_buy_new_physical IS NOT NULL OR price_buy_new_digital IS NOT NULL OR price_buy_new_na IS NOT NULL OR
         price_buy_used_physical IS NOT NULL OR price_buy_used_digital IS NOT NULL OR price_buy_used_na IS NOT NULL OR
         price_buy_na_physical IS NOT NULL OR price_buy_na_digital IS NOT NULL OR price_buy_na_na IS NOT NULL) AS has_buy,
        (price_rental_new_physical IS NOT NULL OR price_rental_new_digital IS NOT NULL OR price_rental_new_na IS NOT NULL OR
         price_rental_used_physical IS NOT NULL OR price_rental_used_digital IS NOT NULL OR price_rental_used_na IS NOT NULL OR
         price_rental_na_physical IS NOT NULL OR price_rental_na_digital IS NOT NULL OR price_rental_na_na IS NOT NULL) AS has_rental
    FROM pricing_wide
)
SELECT
    'Buy/rental coverage' AS metric,
    COUNT(*) FILTER (WHERE has_buy AND has_rental)        AS both,
    COUNT(*) FILTER (WHERE has_buy AND NOT has_rental)    AS buy_only,
    COUNT(*) FILTER (WHERE NOT has_buy AND has_rental)    AS rental_only,
    COUNT(*) FILTER (WHERE NOT has_buy AND NOT has_rental) AS neither
FROM classified;

-- DQ: price_avg sanity — must lie between price_min and price_max by definition
SELECT
    'price_avg sanity' AS metric,
    COUNT(*) FILTER (WHERE price_avg < price_min) AS rows_below_min,
    COUNT(*) FILTER (WHERE price_avg > price_max) AS rows_above_max,
    COUNT(*) FILTER (WHERE price_min IS NULL OR price_max IS NULL) AS rows_with_null_bounds
FROM pricing_wide;
