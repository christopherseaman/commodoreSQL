-- Build section-level filter based on catalog book_status
-- Sections with any Required rows: include only Required materials
-- Sections without Required rows: include only NULL-status materials
-- Only periods from 2024 onward

${CONFIG}

BEGIN TRANSACTION;

DROP TABLE IF EXISTS section_book_status;
DROP VIEW IF EXISTS catalog_filtered;

-- One row per section_id with has_required flag from catalog
CREATE TABLE section_book_status AS
SELECT
    section_id,
    COALESCE(BOOL_OR(book_status = 'required'), FALSE) AS has_required
FROM ${SURVEY_TABLE}
GROUP BY section_id;

CREATE INDEX idx_sbs_section ON section_book_status (section_id);

-- Filtered catalog: period >= 2024 + book_status logic
CREATE VIEW catalog_filtered AS
SELECT c.*
FROM ${SURVEY_TABLE} c
JOIN section_book_status s ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
  AND (
    (s.has_required = TRUE AND c.book_status = 'required')
    OR
    (s.has_required = FALSE AND c.book_status IS NULL)
  );

COMMIT;

-- Summary statistics
SELECT 'Total catalog sections' AS metric, COUNT(*)::VARCHAR AS value FROM section_book_status
UNION ALL
SELECT 'Sections with has_required=TRUE', COUNT(*)::VARCHAR FROM section_book_status WHERE has_required = TRUE
UNION ALL
SELECT 'Sections with has_required=FALSE', COUNT(*)::VARCHAR FROM section_book_status WHERE has_required = FALSE
UNION ALL
SELECT 'Sections with has_required=NULL', COUNT(*)::VARCHAR FROM section_book_status WHERE has_required IS NULL
UNION ALL
SELECT 'Filtered catalog rows', COUNT(*)::VARCHAR FROM catalog_filtered;
