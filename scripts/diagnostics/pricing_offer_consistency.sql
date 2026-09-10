-- Investigation only; not part of the ETL runner. Fall 2025 retained observations.
-- duckdb -bail -readonly -json duckdb/commodore.duckdb < scripts/diagnostics/pricing_offer_consistency.sql
SET threads=2;
SET memory_limit='4GB';
CREATE TEMP TABLE observations AS
SELECT unit_id,isbn13,section_id,bookstore_url,pricing_date,book_option,
 book_condition,book_format,rental_days,price,dept_code,course_code,section_code,
 title,edition,book_status,return_date
FROM pricing_historical WHERE period_sortable='2025-4' AND unit_id IS NOT NULL
 AND isbn13 IS NOT NULL;
SELECT 'source_scope' AS metric,count(*) AS rows,
 count(DISTINCT pricing_date) AS timestamps,min(pricing_date) AS earliest,
 max(pricing_date) AS latest,
 count(*) FILTER(WHERE pricing_date IS NULL) AS missing_timestamp_rows
FROM observations WHERE isbn13<>'0';

-- Compare offer values, not section min/max across unlike formats or rental terms.
CREATE TEMP TABLE term_offers AS
SELECT unit_id,isbn13,book_option,book_condition,book_format,rental_days,
 count(DISTINCT section_id) AS sections,
 count(DISTINCT price) FILTER(WHERE price<9999) AS valid_prices
FROM observations GROUP BY ALL;
SELECT 'term_offer_consistency' AS metric,
 CASE WHEN isbn13='0' THEN 'zero identifier'
      WHEN regexp_full_match(isbn13,'[0-9]{13}') THEN '13 digits'
      ELSE 'other identifier' END AS identifier_scope,
 count(*) AS repeated_groups,
 count(*) FILTER(WHERE valid_prices>0) AS valid_groups,
 count(*) FILTER(WHERE valid_prices=1) AS one_price_groups,
 count(*) FILTER(WHERE valid_prices>1) AS disagreeing_groups
FROM term_offers WHERE sections>1 GROUP BY identifier_scope;

CREATE TEMP TABLE timestamp_offers AS
SELECT unit_id,isbn13,book_option,book_condition,book_format,rental_days,
 pricing_date,bookstore_url,count(DISTINCT section_id) AS sections,
 count(DISTINCT price) FILTER(WHERE price<9999) AS valid_prices
FROM observations
WHERE pricing_date IS NOT NULL AND bookstore_url IS NOT NULL
GROUP BY ALL;
SELECT 'same_timestamp_store_consistency' AS metric,
 CASE WHEN isbn13='0' THEN 'zero identifier'
      WHEN regexp_full_match(isbn13,'[0-9]{13}') THEN '13 digits'
      ELSE 'other identifier' END AS identifier_scope,
 count(*) AS repeated_groups,
 count(*) FILTER(WHERE valid_prices>0) AS valid_groups,
 count(*) FILTER(WHERE valid_prices=1) AS one_price_groups,
 count(*) FILTER(WHERE valid_prices>1) AS disagreeing_groups
FROM timestamp_offers WHERE sections>1 GROUP BY identifier_scope;

SELECT 'documented_same_timestamp_examples' AS metric,*
FROM observations WHERE unit_id=100751
 AND ((isbn13='9780013826132' AND pricing_date=TIMESTAMP '2025-11-04 10:03:48')
   OR (isbn13='9780013869771' AND pricing_date=TIMESTAMP '2025-11-03 21:52:06'))
 AND book_option='buy' AND book_condition='new' AND book_format='digital'
ORDER BY isbn13,section_code;
