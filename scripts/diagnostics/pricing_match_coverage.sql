-- Investigation only; not part of the ETL runner.
-- Fall 2025 coverage, candidate ambiguity, and leave-one-section-out comparison.
-- duckdb -bail -readonly -json duckdb/commodore.duckdb < scripts/diagnostics/pricing_match_coverage.sql
SET threads=2;
SET memory_limit='4GB';
CREATE TEMP TABLE p AS
SELECT *, split_part(section_id, '::', 2) AS department_key,
          split_part(section_id, '::', 3) AS course_key
FROM pricing_wide WHERE split_part(section_id, '::', 5)='2025-4';
CREATE TEMP TABLE candidates AS
SELECT unit_id, isbn13, count(*) AS pricing_sections,
 count(DISTINCT bookstore_url) AS bookstores,
 count(*) FILTER (WHERE bookstore_url IS NULL) AS null_bookstores,
 count(*) FILTER (WHERE price_min IS NOT NULL) AS valid_sections,
 count(DISTINCT (price_min,price_max,price_buy_min,price_buy_max)) AS bound_variants,
 count(DISTINCT (
 price_buy_new_physical,price_buy_new_digital,price_buy_new_na,
 price_buy_used_physical,price_buy_used_digital,price_buy_used_na,
 price_buy_na_physical,price_buy_na_digital,price_buy_na_na,
 price_rental_new_physical,price_rental_new_digital,price_rental_new_na,
 price_rental_used_physical,price_rental_used_digital,price_rental_used_na,
 price_rental_na_physical,price_rental_na_digital,price_rental_na_na,
 price_min,price_max,price_buy_min,price_buy_max,
 rental_days_min,rental_days_max,format_count,has_buy,has_rent
 )) AS payload_variants
FROM p WHERE unit_id IS NOT NULL AND isbn13 IS NOT NULL GROUP BY unit_id,isbn13;
CREATE TEMP TABLE items AS
SELECT m.section_id,m.unit_id,CAST(m.isbn13 AS VARCHAR) AS isbn13,
 m.has_pricing_match,m.price_min IS NOT NULL AS has_valid_price,
 m.is_required_inferred,
 c.pricing_sections,c.bookstores,c.null_bookstores,c.valid_sections,c.bound_variants,c.payload_variants
FROM master_material m LEFT JOIN candidates c
 ON m.unit_id=c.unit_id AND CAST(m.isbn13 AS VARCHAR)=c.isbn13
WHERE m.period_sortable='2025-4';
SELECT 'fall2025_material_coverage' AS metric,
 count(*) AS materials,count(*) FILTER(WHERE has_pricing_match) AS exact_matches,
 count(*) FILTER(WHERE has_valid_price) AS exact_valid_prices,
 count(*) FILTER(WHERE pricing_sections IS NOT NULL) AS institution_isbn_candidates,
 count(*) FILTER(WHERE NOT has_pricing_match AND pricing_sections IS NOT NULL) AS possible_recoveries,
 count(*) FILTER(WHERE NOT has_pricing_match AND valid_sections>0) AS recoveries_with_valid_price,
 count(*) FILTER(WHERE NOT has_pricing_match AND valid_sections>0 AND payload_variants=1) AS identical_payload_recoveries,
 count(*) FILTER(WHERE NOT has_pricing_match AND valid_sections>0 AND payload_variants=1 AND bookstores=1 AND null_bookstores=0) AS single_store_identical_payload_recoveries,
 count(*) FILTER(WHERE NOT has_pricing_match AND valid_sections>0 AND payload_variants>1) AS varying_payload_recoveries,
 count(*) FILTER(WHERE NOT has_pricing_match AND pricing_sections IS NULL) AS no_institution_isbn_candidate
FROM items;
SELECT 'candidate_groups' AS metric,count(*) AS groups,
 count(*) FILTER(WHERE pricing_sections>1) AS multi_section_groups,
 count(*) FILTER(WHERE pricing_sections>1 AND payload_variants=1) AS identical_multi_section_payloads,
 count(*) FILTER(WHERE pricing_sections>1 AND bound_variants=1) AS identical_multi_section_bounds,
 count(*) FILTER(WHERE bookstores>1) AS multi_bookstore_groups,
 count(*) FILTER(WHERE null_bookstores>0) AS null_bookstore_groups
FROM candidates;
SELECT 'recovery_by_requiredness' AS metric,is_required_inferred,count(*) AS materials,
 count(*) FILTER(WHERE has_pricing_match) AS exact_matches,
 count(*) FILTER(WHERE NOT has_pricing_match AND pricing_sections IS NOT NULL) AS possible_recoveries,
 count(*) FILTER(WHERE NOT has_pricing_match AND valid_sections>0 AND payload_variants=1 AND bookstores=1 AND null_bookstores=0) AS single_store_identical_payload_recoveries
FROM items GROUP BY is_required_inferred;
SELECT 'recovery_by_payload' AS metric,
 CASE WHEN pricing_sections=1 THEN 'one source section'
      WHEN payload_variants=1 THEN 'multiple sections, identical payload'
      ELSE 'multiple sections, varying payload' END AS candidate_class,
 count(*) AS unmatched_materials,
 count(*) FILTER(WHERE bound_variants=1) AS identical_bounds,
 count(*) FILTER(WHERE bookstores>1) AS multiple_bookstores
FROM items WHERE NOT has_pricing_match AND pricing_sections IS NOT NULL GROUP BY candidate_class;
SELECT 'identity_safety' AS metric,count(*) AS rows,
 count(*)-count(DISTINCT(section_id,isbn13)) AS duplicate_item_keys
FROM items;
-- Mask each exact-match section and ask whether all remaining peer sections
-- agree. This measures whether unanimous peers can still differ from the held-out payload.
CREATE TEMP TABLE pp AS
SELECT unit_id,isbn13,section_id,bookstore_url,
 list_value(price_buy_new_physical,price_buy_new_digital,price_buy_new_na,
 price_buy_used_physical,price_buy_used_digital,price_buy_used_na,
 price_buy_na_physical,price_buy_na_digital,price_buy_na_na,
 price_rental_new_physical,price_rental_new_digital,price_rental_new_na,
 price_rental_used_physical,price_rental_used_digital,price_rental_used_na,
 price_rental_na_physical,price_rental_na_digital,price_rental_na_na,
 price_min,price_max,price_buy_min,price_buy_max,
 rental_days_min,rental_days_max,format_count,has_buy::INTEGER,has_rent::INTEGER) AS payload
FROM p;
CREATE TEMP TABLE variants AS
SELECT unit_id,isbn13,payload,count(*) AS own_variant_sections
FROM pp GROUP BY unit_id,isbn13,payload;
-- Two total variants minus a unique held-out variant leaves exactly one peer
-- variant, which necessarily differs from the held-out payload.
SELECT 'masked_exact_matches' AS metric,count(*) AS exact_with_peers,
 count(*) FILTER(WHERE c.payload_variants=1) AS unanimous_agrees_with_held_out,
 count(*) FILTER(WHERE c.payload_variants=2 AND v.own_variant_sections=1) AS unanimous_disagrees_with_held_out,
 count(*) FILTER(WHERE c.payload_variants=1 AND c.bookstores=1) AS single_store_unanimous_agrees_with_held_out,
 count(*) FILTER(WHERE c.payload_variants=2 AND v.own_variant_sections=1 AND c.bookstores=1) AS single_store_unanimous_disagrees_with_held_out
FROM items i JOIN pp ON i.section_id=pp.section_id AND i.isbn13=pp.isbn13
 JOIN candidates c ON pp.unit_id=c.unit_id AND pp.isbn13=c.isbn13
 JOIN variants v ON pp.unit_id=v.unit_id AND pp.isbn13=v.isbn13 AND pp.payload=v.payload
WHERE i.has_pricing_match AND c.pricing_sections>1;
SELECT 'candidate_isbn_structure' AS metric,
 CASE WHEN isbn13='0' THEN 'zero identifier'
      WHEN regexp_full_match(isbn13,'[0-9]{13}') THEN '13 digits (checksum not checked)'
      ELSE 'other source identifier' END AS identifier_class,
 count(*) AS possible_recoveries,
 count(*) FILTER(WHERE payload_variants=1 AND bookstores=1 AND null_bookstores=0) AS single_store_identical_payload
FROM items WHERE NOT has_pricing_match AND pricing_sections IS NOT NULL GROUP BY identifier_class;
-- The wide table's MAX(bookstore_url) can hide multiple source URLs. Inspect
-- retained tall observations before treating a candidate as single-store.
CREATE TEMP TABLE source_context AS
SELECT unit_id,isbn13,count(DISTINCT bookstore_url) AS source_stores,
 count(*) FILTER(WHERE bookstore_url IS NULL OR trim(bookstore_url)='') AS missing_store_rows,
 count(DISTINCT pricing_date) AS source_timepoints,
 count(*) FILTER(WHERE pricing_date IS NULL) AS missing_time_rows,
 min(pricing_date) AS first_time,max(pricing_date) AS last_time
FROM pricing_historical WHERE period_sortable='2025-4'
GROUP BY unit_id,isbn13;
SELECT 'retained_source_guarded_recovery' AS metric,
 count(*) AS possible_recoveries,
 count(*) FILTER(WHERE c.source_stores>1) AS multiple_retained_source_stores,
 count(*) FILTER(WHERE i.payload_variants=1 AND c.source_stores=1 AND c.missing_store_rows=0) AS identical_payload_one_source_store,
 count(*) FILTER(WHERE i.payload_variants=1 AND c.source_stores=1 AND c.missing_store_rows=0 AND c.source_timepoints=1 AND c.missing_time_rows=0) AS also_one_recorded_timepoint,
 count(*) FILTER(WHERE i.payload_variants=1 AND c.source_stores=1 AND c.missing_store_rows=0 AND c.source_timepoints>1) AS multiple_recorded_timepoints,
 count(*) FILTER(WHERE i.payload_variants=1 AND c.source_stores=1 AND c.missing_store_rows=0 AND i.pricing_sections=1) AS only_one_source_section
FROM items i JOIN source_context c USING(unit_id,isbn13)
WHERE NOT i.has_pricing_match;
