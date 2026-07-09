-- Add OER/IA classification to pricing_historical
-- Source: comprehensive_data, joined on (section_id, ISBN13).
-- BOOL_OR is taken as the definitive value; a console DQ check compares OR vs AND.
-- TODO: better DQ logging (e.g., write inconsistencies to a TSV) — currently console-only.

${CONFIG}

BEGIN TRANSACTION;

ALTER TABLE pricing_historical ADD COLUMN IF NOT EXISTS is_oer BOOLEAN;
ALTER TABLE pricing_historical ADD COLUMN IF NOT EXISTS is_ia  BOOLEAN;

-- Pre-aggregate per (section_id, isbn13) to avoid join multiplication
-- (comprehensive_data has ~2x rows per pair).
CREATE OR REPLACE TEMP TABLE oer_ia_per_section_isbn AS
SELECT
    section_id,
    ISBN13 AS isbn13,
    BOOL_OR(is_oer)  AS is_oer_or,
    BOOL_AND(is_oer) AS is_oer_and,
    BOOL_OR(is_ia)   AS is_ia_or,
    BOOL_AND(is_ia)  AS is_ia_and
FROM comprehensive_data
GROUP BY section_id, ISBN13;

UPDATE pricing_historical p
SET is_oer = o.is_oer_or,
    is_ia  = o.is_ia_or
FROM oer_ia_per_section_isbn o
WHERE p.section_id = o.section_id
  AND p.isbn13     = o.isbn13;

-- Build pricing_historical indexes HERE (#49), after the LAST write to the table
-- (this UPDATE plus 1b_section_filter.sql's UPDATEs). A DuckDB ART index created
-- earlier (1_bookprices_import.sql) then UPDATE'd gets corrupted for '=' point
-- lookups — WHERE period_sortable = 'x' silently returns 0 rows. DROP+CREATE here,
-- post-write, keeps '=' correct. Re-runnable via DROP IF EXISTS.
DROP INDEX IF EXISTS idx_pricing_section;
DROP INDEX IF EXISTS idx_pricing_isbn;
DROP INDEX IF EXISTS idx_pricing_period;
CREATE INDEX idx_pricing_section ON pricing_historical (section_id);
CREATE INDEX idx_pricing_isbn    ON pricing_historical (isbn13);
CREATE INDEX idx_pricing_period  ON pricing_historical (period_sortable);

COMMIT;

-- DQ check: BOOL_OR should equal BOOL_AND for every (section, isbn) — flags inconsistent classification
SELECT
    'OER/IA classification consistency' AS metric,
    COUNT(*)                                                                AS section_isbn_pairs,
    SUM(CASE WHEN is_oer_or IS NOT DISTINCT FROM is_oer_and THEN 0 ELSE 1 END) AS oer_inconsistent_pairs,
    SUM(CASE WHEN is_ia_or  IS NOT DISTINCT FROM is_ia_and  THEN 0 ELSE 1 END) AS ia_inconsistent_pairs
FROM oer_ia_per_section_isbn;

DROP TABLE IF EXISTS oer_ia_per_section_isbn;

-- Coverage: how many pricing rows got an OER/IA classification?
SELECT
    'pricing_historical OER/IA coverage' AS metric,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN is_oer IS NOT NULL THEN 1 ELSE 0 END) AS rows_with_oer,
    SUM(CASE WHEN is_ia  IS NOT NULL THEN 1 ELSE 0 END) AS rows_with_ia
FROM pricing_historical;

-- DQ: Pricing → catalog match rate by period (surfaces drift if periods stop matching)
SELECT
    'Pricing → catalog match by period' AS check_name,
    period_sortable,
    COUNT(*) AS pricing_rows,
    SUM(CASE WHEN is_oer IS NOT NULL THEN 1 ELSE 0 END) AS rows_matched,
    ROUND(100.0 * SUM(CASE WHEN is_oer IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS match_pct
FROM pricing_historical
GROUP BY period_sortable
ORDER BY period_sortable;

-- DQ: pricing section coverage by is_required_inferred slice
-- Finding from 2026-05-05 investigation: is_required_inferred=TRUE pricing sections are 100% matched in
-- catalog; the ~33% unmatched lives entirely in is_required_inferred=FALSE rows (pre-2024 / non-required
-- materials). So unmatched sections don't affect filtered analysis but indicate older bookstore
-- data without a corresponding catalog entry. See TODO.md for normalization plan.
WITH pricing_secs AS (
    SELECT DISTINCT is_required_inferred, unit_id, period_sortable, section_id
    FROM pricing_historical
),
catalog_secs AS (SELECT DISTINCT section_id FROM comprehensive_data)
SELECT
    'Pricing → catalog section coverage' AS metric,
    p.is_required_inferred,
    COUNT(*) AS pricing_sections,
    SUM(CASE WHEN c.section_id IS NULL THEN 1 ELSE 0 END) AS unmatched,
    ROUND(100.0 * SUM(CASE WHEN c.section_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS unmatched_pct
FROM pricing_secs p
LEFT JOIN catalog_secs c USING (section_id)
GROUP BY p.is_required_inferred
ORDER BY p.is_required_inferred DESC;

-- Top (unit, period) for is_required_inferred=FALSE unmatched sections — actionable for normalization
WITH pricing_secs AS (
    SELECT DISTINCT unit_id, period_sortable, section_id
    FROM pricing_historical
    WHERE is_required_inferred = FALSE
),
catalog_secs AS (SELECT DISTINCT section_id FROM comprehensive_data)
SELECT
    'Top (unit, period) by unmatched pricing sections (is_required_inferred=FALSE)' AS check_name,
    p.unit_id,
    p.period_sortable,
    COUNT(*) AS pricing_sections,
    SUM(CASE WHEN c.section_id IS NULL THEN 1 ELSE 0 END) AS unmatched,
    ROUND(100.0 * SUM(CASE WHEN c.section_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS unmatched_pct
FROM pricing_secs p
LEFT JOIN catalog_secs c USING (section_id)
GROUP BY p.unit_id, p.period_sortable
HAVING SUM(CASE WHEN c.section_id IS NULL THEN 1 ELSE 0 END) > 100
ORDER BY unmatched DESC
LIMIT 10;
