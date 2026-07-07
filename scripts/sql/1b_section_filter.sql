-- Build section-level filter based on catalog book_status
-- Sections with any Required rows: include only Required materials
-- Sections without Required rows: include only NULL-status materials
-- Only periods from 2024 onward

${CONFIG}

BEGIN TRANSACTION;

DROP TABLE IF EXISTS section_book_status;

-- One row per section_id with has_required flag from catalog.
-- #40: has_required is SUPPLY-AWARE — a supply item marked 'required' (e.g. safety
-- goggles) must NOT make the section "has a required book", else a co-listed real
-- textbook with blank status is wrongly denied the has_required=FALSE fallback and
-- ends up optional. So has_required = BOOL_OR(required AND NOT supply). Supply status
-- comes from supply_isbn_classification, built one stage earlier (1a_). The legacy
-- (contaminated) value is computed alongside purely to log the correction delta to
-- console (Boolean-DQ-pair convention, CLAUDE.md); it is never stored.
CREATE OR REPLACE TEMP TABLE section_book_status_calc AS
SELECT
    c.section_id,
    COALESCE(BOOL_OR(c.book_status = 'required' AND si.isbn13 IS NULL), FALSE) AS has_required,
    COALESCE(BOOL_OR(c.book_status = 'required'), FALSE)                       AS legacy_has_required
FROM ${SURVEY_TABLE} c
LEFT JOIN supply_isbn_classification si ON c."ISBN13" = si.isbn13
GROUP BY c.section_id;

CREATE TABLE section_book_status AS
SELECT section_id, has_required FROM section_book_status_calc;

CREATE INDEX idx_sbs_section ON section_book_status (section_id);

-- Add is_required_inferred to pricing_historical
-- (comprehensive_data gets is_required_inferred in 2_oer_classification.sql where it is recreated)
-- Idempotent: ADD COLUMN IF NOT EXISTS (not DROP+ADD — DuckDB refuses to DROP a column
-- on a table that has dependents), then reset every row to FALSE so the conditional
-- UPDATE below is a clean re-derivation that never retains a stale TRUE from a prior
-- has_required definition.
ALTER TABLE pricing_historical ADD COLUMN IF NOT EXISTS is_required_inferred BOOLEAN DEFAULT FALSE;
UPDATE pricing_historical SET is_required_inferred = FALSE;

UPDATE pricing_historical p
SET is_required_inferred = TRUE
FROM section_book_status s
WHERE p.section_id = s.section_id
  AND p.period_date >= '2024-01-01'
  AND (
    (s.has_required = TRUE  AND p.book_status = 'required')
    OR
    (s.has_required = FALSE AND p.book_status IS NULL)
  );

COMMIT;

-- Summary statistics
SELECT 'Total catalog sections' AS metric, COUNT(*)::VARCHAR AS value FROM section_book_status
UNION ALL
SELECT 'Sections with has_required=TRUE', COUNT(*)::VARCHAR FROM section_book_status WHERE has_required = TRUE
UNION ALL
SELECT 'Sections with has_required=FALSE', COUNT(*)::VARCHAR FROM section_book_status WHERE has_required = FALSE
UNION ALL
SELECT 'Sections with has_required=NULL', COUNT(*)::VARCHAR FROM section_book_status WHERE has_required IS NULL;

-- DQ (#40, console-only): how many sections the supply-aware fix corrected. A supply
-- item can only NARROW a BOOL_OR, so flips are one-directional (TRUE->FALSE); a nonzero
-- false_to_true would signal a logic bug.
SELECT 'has_required supply-contamination corrected (#40)' AS metric,
       COUNT(*) FILTER (WHERE legacy_has_required AND NOT has_required) AS sections_true_to_false,
       COUNT(*) FILTER (WHERE NOT legacy_has_required AND has_required) AS sections_false_to_true
FROM section_book_status_calc;

DROP TABLE IF EXISTS section_book_status_calc;

SELECT 'pricing_historical is_required_inferred' AS table_name, is_required_inferred, COUNT(*)::VARCHAR AS row_count
FROM pricing_historical GROUP BY is_required_inferred;

-- DQ: section_book_status should cover every catalog section_id (built via GROUP BY catalog).
-- Nonzero diff would indicate a code bug.
SELECT
    'section_book_status coverage' AS metric,
    (SELECT COUNT(DISTINCT section_id) FROM ${SURVEY_TABLE}) AS catalog_distinct_sections,
    (SELECT COUNT(*) FROM section_book_status)               AS sbs_rows,
    (SELECT COUNT(DISTINCT section_id) FROM ${SURVEY_TABLE})
        - (SELECT COUNT(*) FROM section_book_status)         AS uncovered_sections;
