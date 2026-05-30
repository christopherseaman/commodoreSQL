-- Data Quality tables — surface for BI dashboards.
-- One scalar-metrics table + a handful of side tables for distributions/top-N lists.
-- Recreated on each pipeline run (snapshot of latest state; trending would require
-- appending with a measured_at column — see TODO.md).

${CONFIG}

-- =====================================================================
-- Scalar metrics (long-format)
-- =====================================================================

DROP TABLE IF EXISTS __data_quality_metrics;
CREATE TABLE __data_quality_metrics (
    category     VARCHAR,
    check_id     VARCHAR,
    metric_name  VARCHAR,
    metric_value BIGINT
);

-- All catalog checks are scoped to filter_include = TRUE (analytical subset:
-- period >= 2024-01-01 with the has_required / book_status logic from 1b_section_filter.sql).
-- Source-quality of pre-2024 / non-required rows is acknowledged but not surfaced here.

-- Catalog: composite-key UNKNOWN segments + null period
INSERT INTO __data_quality_metrics
SELECT 'catalog', 'composite_key_unknowns', 'section_id_unknown_rows', COUNT(*) FILTER (WHERE section_id LIKE '%UNKNOWN%') FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'composite_key_unknowns', 'course_id_unknown_rows', COUNT(*) FILTER (WHERE course_id LIKE '%UNKNOWN%') FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'composite_key_unknowns', 'period_sortable_null',  COUNT(*) FILTER (WHERE period_sortable IS NULL) FROM comprehensive_data WHERE filter_include = TRUE;

-- Catalog → IPEDS match (filter_include = TRUE)
INSERT INTO __data_quality_metrics
SELECT 'catalog', 'ipeds_match', 'total_rows',                  COUNT(*) FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'ipeds_match', 'no_unit_id_likely_canadian', COUNT(*) FROM comprehensive_data WHERE filter_include = TRUE AND unit_id IS NULL
UNION ALL SELECT 'catalog', 'ipeds_match', 'unit_id_not_in_ipeds',       COUNT(*) FROM comprehensive_data WHERE filter_include = TRUE AND unit_id IS NOT NULL AND institution_name IS NULL;

-- Catalog: email validity (loose)
INSERT INTO __data_quality_metrics
SELECT 'catalog', 'email_validity', 'email_null',      COUNT(*) FILTER (WHERE email IS NULL) FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'email_validity', 'email_no_at',     COUNT(*) FILTER (WHERE email IS NOT NULL AND email NOT LIKE '%@%') FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'email_validity', 'email_no_dot',    COUNT(*) FILTER (WHERE email IS NOT NULL AND email LIKE '%@%' AND email NOT LIKE '%.%') FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'email_validity', 'email_too_short', COUNT(*) FILTER (WHERE email IS NOT NULL AND LENGTH(email) < 5) FROM comprehensive_data WHERE filter_include = TRUE;

-- Catalog: enrollment sanity
INSERT INTO __data_quality_metrics
SELECT 'catalog', 'enrollment_sanity', 'enrollments_negative',         COUNT(*) FILTER (WHERE enrollments < 0) FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'enrollment_sanity', 'seats_taken_sentinel_9999', COUNT(*) FILTER (WHERE seats_taken = 9999) FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'enrollment_sanity', 'overage_small_1_to_5',
    COUNT(*) FILTER (WHERE seats_taken > enrollments AND seats_taken < 9999 AND seats_taken - enrollments BETWEEN 1 AND 5) FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'enrollment_sanity', 'overage_medium_6_to_100',
    COUNT(*) FILTER (WHERE seats_taken > enrollments AND seats_taken < 9999 AND seats_taken - enrollments BETWEEN 6 AND 100) FROM comprehensive_data WHERE filter_include = TRUE
UNION ALL SELECT 'catalog', 'enrollment_sanity', 'overage_large_over_100',
    COUNT(*) FILTER (WHERE seats_taken > enrollments AND seats_taken < 9999 AND seats_taken - enrollments > 100) FROM comprehensive_data WHERE filter_include = TRUE;

-- Pricing dedupe stages — the headline DQ block from the import
WITH src AS (
    -- Recompute snapshot counts from final pricing_historical (raw counts cached separately would be
    -- nicer but require extending 1_bookprices_import.sql to persist them; for the dashboard we
    -- can recompute by reading the raw CSV here)
    SELECT COUNT(*)::BIGINT AS raw_rows FROM read_csv('${PRICING_CSV}',
        compression='auto', header=true, delim=',', quote='"', escape='"',
        nullstr=['N/A','','Not applicable'],
        types={'CRN':'VARCHAR','ISBN13':'VARCHAR','Edition':'VARCHAR','Rental Length':'VARCHAR'})
)
INSERT INTO __data_quality_metrics
SELECT 'pricing', 'dedupe_stages', 'raw_csv_rows',         raw_rows FROM src
UNION ALL SELECT 'pricing', 'dedupe_stages', 'final_rows',                  (SELECT COUNT(*) FROM pricing_historical)
UNION ALL SELECT 'pricing', 'dedupe_stages', 'rows_removed_by_dedupe',      raw_rows - (SELECT COUNT(*) FROM pricing_historical) FROM src;

-- Pricing residual grain — should be 0 after dedupe
INSERT INTO __data_quality_metrics
SELECT 'pricing', 'residual_grain', 'unexplained_residual',
    COUNT(*) - COUNT(DISTINCT (section_id, isbn13, book_option, book_condition, book_format, rental_days))
FROM pricing_historical;

-- Pricing price outliers
INSERT INTO __data_quality_metrics
SELECT 'pricing', 'price_outliers', 'price_null',     COUNT(*) FILTER (WHERE price IS NULL) FROM pricing_historical
UNION ALL SELECT 'pricing', 'price_outliers', 'price_zero',     COUNT(*) FILTER (WHERE price = 0) FROM pricing_historical
UNION ALL SELECT 'pricing', 'price_outliers', 'price_under_1',  COUNT(*) FILTER (WHERE price > 0 AND price < 1) FROM pricing_historical
UNION ALL SELECT 'pricing', 'price_outliers', 'price_over_1000', COUNT(*) FILTER (WHERE price > 1000) FROM pricing_historical;

-- Pricing buy/rental discipline
INSERT INTO __data_quality_metrics
SELECT 'pricing', 'buy_rental_discipline', 'option_null_with_price',         COUNT(*) FILTER (WHERE book_option IS NULL AND price IS NOT NULL) FROM pricing_historical
UNION ALL SELECT 'pricing', 'buy_rental_discipline', 'buy_with_rental_days',          COUNT(*) FILTER (WHERE book_option = 'buy' AND rental_days IS NOT NULL) FROM pricing_historical
UNION ALL SELECT 'pricing', 'buy_rental_discipline', 'rental_without_rental_days',    COUNT(*) FILTER (WHERE book_option = 'rental' AND rental_days IS NULL) FROM pricing_historical
UNION ALL SELECT 'pricing', 'buy_rental_discipline', 'rental_days_zero',              COUNT(*) FILTER (WHERE book_option = 'rental' AND rental_days = 0) FROM pricing_historical
UNION ALL SELECT 'pricing', 'buy_rental_discipline', 'rental_days_over_5yr',          COUNT(*) FILTER (WHERE book_option = 'rental' AND rental_days > 1825) FROM pricing_historical;

-- Pricing rental_days digital consistency
WITH digital_per_pair AS (
    SELECT section_id, isbn13,
        COUNT(*) FILTER (WHERE rental_days IS NULL)     AS digital_null,
        COUNT(*) FILTER (WHERE rental_days IS NOT NULL) AS digital_set
    FROM pricing_historical
    WHERE book_option = 'rental' AND book_format = 'digital'
    GROUP BY section_id, isbn13
)
INSERT INTO __data_quality_metrics
SELECT 'pricing', 'digital_rental_days_consistency', 'pairs_with_digital_rental', COUNT(*) FROM digital_per_pair
UNION ALL SELECT 'pricing', 'digital_rental_days_consistency', 'all_null_consistent',       COUNT(*) FILTER (WHERE digital_null > 0 AND digital_set = 0) FROM digital_per_pair
UNION ALL SELECT 'pricing', 'digital_rental_days_consistency', 'all_set_consistent',        COUNT(*) FILTER (WHERE digital_null = 0 AND digital_set > 0) FROM digital_per_pair
UNION ALL SELECT 'pricing', 'digital_rental_days_consistency', 'mixed_real_dq_issue',       COUNT(*) FILTER (WHERE digital_null > 0 AND digital_set > 0) FROM digital_per_pair;

-- Pricing UNKNOWN segments
INSERT INTO __data_quality_metrics
SELECT 'pricing', 'unknown_segments', 'rows_with_unknown_segment',     COUNT(*) FILTER (WHERE section_id LIKE '%UNKNOWN%') FROM pricing_historical
UNION ALL SELECT 'pricing', 'unknown_segments', 'distinct_section_ids_affected', COUNT(DISTINCT section_id) FILTER (WHERE section_id LIKE '%UNKNOWN%') FROM pricing_historical;

-- OER/IA classification consistency
WITH oer_ia_pairs AS (
    SELECT section_id, ISBN13,
        BOOL_OR(is_oer)  AS is_oer_or, BOOL_AND(is_oer) AS is_oer_and,
        BOOL_OR(is_ia)   AS is_ia_or,  BOOL_AND(is_ia)  AS is_ia_and
    FROM comprehensive_data GROUP BY 1, 2
)
INSERT INTO __data_quality_metrics
SELECT 'oer_ia', 'classification_consistency', 'section_isbn_pairs',     COUNT(*) FROM oer_ia_pairs
UNION ALL SELECT 'oer_ia', 'classification_consistency', 'oer_inconsistent_pairs', COUNT(*) FILTER (WHERE is_oer_or IS DISTINCT FROM is_oer_and) FROM oer_ia_pairs
UNION ALL SELECT 'oer_ia', 'classification_consistency', 'ia_inconsistent_pairs',  COUNT(*) FILTER (WHERE is_ia_or  IS DISTINCT FROM is_ia_and ) FROM oer_ia_pairs;

-- Cross-table: pricing → catalog section coverage by filter_include
INSERT INTO __data_quality_metrics
SELECT 'cross_table', 'pricing_section_coverage_filter_true', 'pricing_sections',
    COUNT(DISTINCT section_id) FROM pricing_historical WHERE filter_include = TRUE
UNION ALL SELECT 'cross_table', 'pricing_section_coverage_filter_true', 'unmatched',
    COUNT(DISTINCT p.section_id) FROM pricing_historical p
    LEFT JOIN (SELECT DISTINCT section_id FROM comprehensive_data) c USING (section_id)
    WHERE p.filter_include = TRUE AND c.section_id IS NULL
UNION ALL SELECT 'cross_table', 'pricing_section_coverage_filter_false', 'pricing_sections',
    COUNT(DISTINCT section_id) FROM pricing_historical WHERE filter_include = FALSE
UNION ALL SELECT 'cross_table', 'pricing_section_coverage_filter_false', 'unmatched',
    COUNT(DISTINCT p.section_id) FROM pricing_historical p
    LEFT JOIN (SELECT DISTINCT section_id FROM comprehensive_data) c USING (section_id)
    WHERE p.filter_include = FALSE AND c.section_id IS NULL;

-- Wide table: tall vs wide DQ + price_avg sanity
WITH tall AS (
    SELECT COUNT(DISTINCT (section_id, isbn13, book_option, book_condition, book_format)) AS tall_keys
    FROM pricing_historical WHERE book_option IN ('buy','rental')
), wide AS (SELECT SUM(format_count) AS wide_sum FROM pricing_wide)
INSERT INTO __data_quality_metrics
SELECT 'wide', 'tall_vs_wide_parity', 'tall_distinct_keys', tall_keys FROM tall
UNION ALL SELECT 'wide', 'tall_vs_wide_parity', 'wide_format_sum',    wide_sum FROM wide
UNION ALL SELECT 'wide', 'tall_vs_wide_parity', 'difference',         (SELECT tall_keys FROM tall) - (SELECT wide_sum FROM wide);

INSERT INTO __data_quality_metrics
SELECT 'wide', 'price_avg_sanity', 'rows_below_min',        COUNT(*) FILTER (WHERE price_avg < price_min) FROM pricing_wide
UNION ALL SELECT 'wide', 'price_avg_sanity', 'rows_above_max',        COUNT(*) FILTER (WHERE price_avg > price_max) FROM pricing_wide
UNION ALL SELECT 'wide', 'price_avg_sanity', 'rows_with_null_bounds', COUNT(*) FILTER (WHERE price_min IS NULL OR price_max IS NULL) FROM pricing_wide;

-- =====================================================================
-- Side tables — distributions and top-N lists for drill-down
-- =====================================================================

-- Top schools missing IPEDS (top 10) — filter_include = TRUE
DROP TABLE IF EXISTS __data_quality_top_unmatched_ipeds_schools;
CREATE TABLE __data_quality_top_unmatched_ipeds_schools AS
SELECT school, unit_id, COUNT(*) AS catalog_rows
FROM comprehensive_data
WHERE filter_include = TRUE AND institution_name IS NULL
GROUP BY school, unit_id ORDER BY catalog_rows DESC LIMIT 10;

-- NULL ISBN13 placeholder breakdown by school (filter_include = TRUE).
-- Globally only 3 placeholder strings exist for NULL-ISBN rows; none are "real missing":
--   *No Book Details*    — non-classroom (research, dissertation, independent study); ~92% of NULLs
--   *No Books Required*  — explicit "no textbook required" (UCI uses this distinctly); ~7.4%
--   *Bad Course*         — explicit data-quality flag from source; ~0.03% but worth surfacing
-- "other" should remain at 0; nonzero would indicate a new placeholder string in source.
DROP TABLE IF EXISTS __data_quality_null_isbn_breakdown;
CREATE TABLE __data_quality_null_isbn_breakdown AS
SELECT
    school,
    COUNT(*) FILTER (WHERE Title = '*No Book Details*')   AS no_book_details,
    COUNT(*) FILTER (WHERE Title = '*No Books Required*') AS no_books_required,
    COUNT(*) FILTER (WHERE Title = '*Bad Course*')        AS bad_course,
    COUNT(*) FILTER (WHERE Title IS NULL
                       OR Title NOT IN ('*No Book Details*', '*No Books Required*', '*Bad Course*')) AS other,
    COUNT(*)                                              AS total_null_isbn
FROM comprehensive_data
WHERE filter_include = TRUE AND ISBN13 IS NULL
GROUP BY school
HAVING COUNT(*) > 0
ORDER BY total_null_isbn DESC
LIMIT 20;

-- Top schools by NULL ISBN13 (top 10) with proportion of NULL vs total rows (filter_include = TRUE)
DROP TABLE IF EXISTS __data_quality_top_null_isbn_schools;
CREATE TABLE __data_quality_top_null_isbn_schools AS
SELECT
    school,
    COUNT(*) FILTER (WHERE ISBN13 IS NULL) AS null_isbn_rows,
    COUNT(*) FILTER (WHERE ISBN13 IS NOT NULL) AS non_null_isbn_rows,
    COUNT(*) AS total_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ISBN13 IS NULL) / COUNT(*), 2) AS null_pct,
    COUNT(DISTINCT section_id) FILTER (WHERE ISBN13 IS NULL) AS distinct_sections
FROM comprehensive_data
WHERE filter_include = TRUE
GROUP BY school
HAVING COUNT(*) FILTER (WHERE ISBN13 IS NULL) > 0
ORDER BY null_isbn_rows DESC LIMIT 10;

-- Pricing → catalog match by period (full table, all periods)
DROP TABLE IF EXISTS __data_quality_pricing_match_by_period;
CREATE TABLE __data_quality_pricing_match_by_period AS
SELECT
    period_sortable,
    COUNT(*) AS pricing_rows,
    SUM(CASE WHEN is_oer IS NOT NULL THEN 1 ELSE 0 END) AS rows_matched,
    ROUND(100.0 * SUM(CASE WHEN is_oer IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS match_pct
FROM pricing_historical
GROUP BY period_sortable ORDER BY period_sortable;

-- Top (unit_id, period) by unmatched pricing sections (filter_include=FALSE)
DROP TABLE IF EXISTS __data_quality_top_unmatched_pricing_sections;
CREATE TABLE __data_quality_top_unmatched_pricing_sections AS
WITH pricing_secs AS (
    SELECT DISTINCT unit_id, period_sortable, section_id FROM pricing_historical WHERE filter_include = FALSE
), catalog_secs AS (SELECT DISTINCT section_id FROM comprehensive_data)
SELECT
    p.unit_id, p.period_sortable,
    COUNT(*) AS pricing_sections,
    SUM(CASE WHEN c.section_id IS NULL THEN 1 ELSE 0 END) AS unmatched,
    ROUND(100.0 * SUM(CASE WHEN c.section_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS unmatched_pct
FROM pricing_secs p LEFT JOIN catalog_secs c USING (section_id)
GROUP BY p.unit_id, p.period_sortable
HAVING SUM(CASE WHEN c.section_id IS NULL THEN 1 ELSE 0 END) > 100
ORDER BY unmatched DESC LIMIT 10;

-- pricing_wide format_count distribution
DROP TABLE IF EXISTS __data_quality_format_count_distribution;
CREATE TABLE __data_quality_format_count_distribution AS
SELECT format_count, COUNT(*) AS pricing_wide_rows
FROM pricing_wide GROUP BY format_count ORDER BY format_count;

-- =====================================================================
-- Final summary print
-- =====================================================================

SELECT category, check_id, metric_name, metric_value
FROM __data_quality_metrics ORDER BY category, check_id, metric_name;

SELECT 'DQ surface ready' AS status,
    (SELECT COUNT(*) FROM __data_quality_metrics) AS scalar_metrics,
    (SELECT COUNT(*) FROM __data_quality_top_unmatched_ipeds_schools) AS top_unmatched_ipeds_rows,
    (SELECT COUNT(*) FROM __data_quality_top_null_isbn_schools) AS top_null_isbn_rows,
    (SELECT COUNT(*) FROM __data_quality_pricing_match_by_period) AS pricing_match_periods,
    (SELECT COUNT(*) FROM __data_quality_top_unmatched_pricing_sections) AS top_unmatched_pricing_rows,
    (SELECT COUNT(*) FROM __data_quality_format_count_distribution) AS format_count_buckets,
    (SELECT COUNT(*) FROM __data_quality_null_isbn_breakdown) AS null_isbn_breakdown_rows;
