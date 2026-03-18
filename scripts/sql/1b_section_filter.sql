-- Build section-level filter based on catalog book_status
-- Sections with any Required rows: include only Required materials
-- Sections without Required rows: include only NULL-status materials
-- Only periods from 2024 onward

${CONFIG}

BEGIN TRANSACTION;

DROP TABLE IF EXISTS section_book_status;

-- One row per section_id with has_required flag from catalog
CREATE TABLE section_book_status AS
SELECT
    section_id,
    COALESCE(BOOL_OR(book_status = 'required'), FALSE) AS has_required
FROM ${SURVEY_TABLE}
GROUP BY section_id;

CREATE INDEX idx_sbs_section ON section_book_status (section_id);

-- Add filter_include to pricing_historical
-- (comprehensive_data gets filter_include in 2_oer_classification.sql where it is recreated)
ALTER TABLE pricing_historical ADD COLUMN filter_include BOOLEAN DEFAULT FALSE;

UPDATE pricing_historical p
SET filter_include = TRUE
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

SELECT 'pricing_historical filter_include' AS table_name, filter_include, COUNT(*)::VARCHAR AS row_count
FROM pricing_historical GROUP BY filter_include;
