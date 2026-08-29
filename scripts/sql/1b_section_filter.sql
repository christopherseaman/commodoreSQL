-- Build the section-level catalog status used by downstream required inference.
-- Sections with any required book use required materials; sections without one
-- use NULL-status materials. The downstream catalog stage applies the period scope.

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

-- DQ: section_book_status should cover every catalog section_id (built via GROUP BY catalog).
-- Nonzero diff would indicate a code bug.
SELECT
    'section_book_status coverage' AS metric,
    (SELECT COUNT(DISTINCT section_id) FROM ${SURVEY_TABLE}) AS catalog_distinct_sections,
    (SELECT COUNT(*) FROM section_book_status)               AS sbs_rows,
    (SELECT COUNT(DISTINCT section_id) FROM ${SURVEY_TABLE})
        - (SELECT COUNT(*) FROM section_book_status)         AS uncovered_sections;
