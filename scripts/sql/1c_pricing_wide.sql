-- Wide pricing analysis table: one row per section_id x isbn
-- 18 price columns for each option (buy/rental) x condition (new/used/na) x format (physical/digital/na)
-- Filtered using catalog section_book_status (has_required) and period >= 2024

${CONFIG}

BEGIN TRANSACTION;

DROP TABLE IF EXISTS pricing_wide;

CREATE TABLE pricing_wide AS
SELECT
    p.section_id,
    p.isbn13,
    -- Section-level columns (unique per section_id via unit_id)
    MAX(p.institute) AS institute,
    MAX(p.bookstore_url) AS bookstore_url,
    -- ISBN-level descriptive columns
    MAX(p.title) AS title,
    MAX(p.author) AS author,
    MAX(p.publisher) AS publisher,
    MAX(p.edition) AS edition,
    -- Buy x New
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition = 'new' AND p.book_format = 'physical' THEN p.price END) AS price_buy_new_physical,
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition = 'new' AND p.book_format = 'digital' THEN p.price END) AS price_buy_new_digital,
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition = 'new' AND p.book_format IS NULL THEN p.price END) AS price_buy_new_na,
    -- Buy x Used
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition = 'used' AND p.book_format = 'physical' THEN p.price END) AS price_buy_used_physical,
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition = 'used' AND p.book_format = 'digital' THEN p.price END) AS price_buy_used_digital,
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition = 'used' AND p.book_format IS NULL THEN p.price END) AS price_buy_used_na,
    -- Buy x N/A condition
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition IS NULL AND p.book_format = 'physical' THEN p.price END) AS price_buy_na_physical,
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition IS NULL AND p.book_format = 'digital' THEN p.price END) AS price_buy_na_digital,
    MAX(CASE WHEN p.book_option = 'buy' AND p.book_condition IS NULL AND p.book_format IS NULL THEN p.price END) AS price_buy_na_na,
    -- Rental x New
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition = 'new' AND p.book_format = 'physical' THEN p.price END) AS price_rental_new_physical,
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition = 'new' AND p.book_format = 'digital' THEN p.price END) AS price_rental_new_digital,
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition = 'new' AND p.book_format IS NULL THEN p.price END) AS price_rental_new_na,
    -- Rental x Used
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition = 'used' AND p.book_format = 'physical' THEN p.price END) AS price_rental_used_physical,
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition = 'used' AND p.book_format = 'digital' THEN p.price END) AS price_rental_used_digital,
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition = 'used' AND p.book_format IS NULL THEN p.price END) AS price_rental_used_na,
    -- Rental x N/A condition
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition IS NULL AND p.book_format = 'physical' THEN p.price END) AS price_rental_na_physical,
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition IS NULL AND p.book_format = 'digital' THEN p.price END) AS price_rental_na_digital,
    MAX(CASE WHEN p.book_option = 'rental' AND p.book_condition IS NULL AND p.book_format IS NULL THEN p.price END) AS price_rental_na_na
FROM pricing_historical p
JOIN section_book_status s ON p.section_id = s.section_id
WHERE p.period_date >= '2024-01-01'
  AND (
    (s.has_required = TRUE  AND p.book_status = 'required')
    OR
    (s.has_required = FALSE AND p.book_status IS NULL)
  )
GROUP BY p.section_id, p.isbn13;

CREATE INDEX idx_pw_section ON pricing_wide (section_id);
CREATE INDEX idx_pw_isbn ON pricing_wide (isbn13);

COMMIT;

-- Summary statistics
SELECT 'Wide pricing rows' AS metric, COUNT(*)::VARCHAR AS value FROM pricing_wide
UNION ALL
SELECT 'Unique section_ids', COUNT(DISTINCT section_id)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'Unique ISBNs', COUNT(DISTINCT isbn13)::VARCHAR FROM pricing_wide
UNION ALL
SELECT 'Rows with buy_new_physical', COUNT(*)::VARCHAR FROM pricing_wide WHERE price_buy_new_physical IS NOT NULL
UNION ALL
SELECT 'Rows with rental_new_digital', COUNT(*)::VARCHAR FROM pricing_wide WHERE price_rental_new_digital IS NOT NULL;
