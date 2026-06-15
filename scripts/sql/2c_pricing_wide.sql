-- Wide pricing: one row per (section_id, isbn13).
-- 18 price columns (option × condition × format) plus required/filter_include flags,
-- OER/IA classification, and fact aggregations: format_count, price_min/max/avg, rental_days_min/max.
--
-- pricing_wide          : ALL priced materials (no filter_include filter), materialized as a
--                         TABLE so downstream views (master_section cost columns) join it cheaply.
-- pricing_wide_filtered : the required, in-scope subset (filter_include), as a VIEW on the base.
--
-- filter_include is taken per (section_id, isbn13) via BOOL_OR. ~5k keys (0.08%) carry mixed
-- per-row filter_include (book_status varies within the material); BOOL_OR treats the material as
-- in-scope if any of its rows qualify.
--
-- Note on rentals: `book_option = 'rental'` is the only case with multiple price points per
-- (option × condition × format), since `rental_days` (~95 distinct values) varies by term.
-- The wide pivot collapses these via MAX(price); rental_days_min/max preserve the term range.
--
-- Naming standard for fact aggregations: <dimension>_<aggfunc>. See CLAUDE.md.

${CONFIG}

DROP VIEW  IF EXISTS pricing_wide_filtered;
DROP TABLE IF EXISTS pricing_wide;
DROP VIEW  IF EXISTS pricing_wide;

CREATE TABLE pricing_wide AS
SELECT
    section_id,
    isbn13,
    BOOL_OR(required)       AS required,
    BOOL_OR(filter_include) AS filter_include,
    -- is_oer / is_ia stored on pricing_historical via 2b_pricing_oer_ia.sql
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
    COUNT(DISTINCT (book_option, book_condition, book_format)) FILTER (WHERE book_option IN ('buy', 'rental')) AS format_count,
    -- Option availability: is a buy / rental listing offered for this material?
    -- (presence of the option, independent of price validity — price_buy_min /
    -- rental_days_min indicate priced availability. book_option NULL counts as neither.)
    BOOL_OR(book_option = 'buy')    AS has_buy,
    BOOL_OR(book_option = 'rental') AS has_rent,
    MIN(price) AS price_min,
    MAX(price) AS price_max,
    -- LEGACY definition: price_avg = (min + max) / 2 — NOT the arithmetic mean. See CLAUDE.md.
    (MIN(price) + MAX(price)) / 2.0 AS price_avg,
    MIN(rental_days) FILTER (WHERE book_option = 'rental') AS rental_days_min,
    MAX(rental_days) FILTER (WHERE book_option = 'rental') AS rental_days_max,
    -- owned (buy-only) price range: feeds the "owned" cost columns (rentals omitted)
    MIN(price) FILTER (WHERE book_option = 'buy') AS price_buy_min,
    MAX(price) FILTER (WHERE book_option = 'buy') AS price_buy_max
-- Null out round-nines sentinel/placeholder prices (9999, 9999.99, 99999, 100000,
-- 999999) so they don't inflate cost min/max/sums. Highest real price ~$5,600, so
-- price >= 9999 is treated as "no price" (#27). Adjust the threshold if a real
-- ceiling above that is confirmed.
FROM (SELECT * REPLACE (CASE WHEN price < 9999 THEN price END AS price) FROM pricing_historical)
GROUP BY section_id, isbn13;

CREATE VIEW pricing_wide_filtered AS
SELECT * FROM pricing_wide WHERE filter_include;

-- Summary statistics
SELECT 'Wide pricing rows (all)' AS metric, COUNT(*)::VARCHAR AS value FROM pricing_wide
UNION ALL
SELECT 'Wide pricing rows (filtered)', COUNT(*)::VARCHAR FROM pricing_wide_filtered
UNION ALL
SELECT 'Unique section_ids', COUNT(DISTINCT section_id)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'Unique ISBNs', COUNT(DISTINCT isbn13)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'Required rows', COUNT(*)::VARCHAR FROM pricing_wide WHERE required = TRUE
UNION ALL
SELECT 'Materials with buy option', COUNT(*)::VARCHAR FROM pricing_wide WHERE has_buy
UNION ALL
SELECT 'Materials with rental option', COUNT(*)::VARCHAR FROM pricing_wide WHERE has_rent
UNION ALL
SELECT 'Avg format_count', ROUND(AVG(format_count), 2)::VARCHAR FROM pricing_wide;

-- DQ check: SUM(format_count) in wide should equal the count of distinct
-- (section_id, isbn13, book_option, book_condition, book_format) keys in tall (buy/rental).
-- Now validates the FULL pivot (pricing_wide is unfiltered).
WITH tall AS (
    SELECT COUNT(DISTINCT (section_id, isbn13, book_option, book_condition, book_format)) AS tall_distinct_keys
    FROM pricing_historical
    WHERE book_option IN ('buy', 'rental')
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

-- DQ: price_avg sanity — must lie between price_min and price_max by definition
SELECT
    'price_avg sanity' AS metric,
    COUNT(*) FILTER (WHERE price_avg < price_min) AS rows_below_min,
    COUNT(*) FILTER (WHERE price_avg > price_max) AS rows_above_max,
    COUNT(*) FILTER (WHERE price_min IS NULL OR price_max IS NULL) AS rows_with_null_bounds
FROM pricing_wide;
