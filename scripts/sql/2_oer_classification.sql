-- Add OER (Open Educational Resources) and IA (Inclusive Access) classification
-- Both OER and IA status are derived from FormatType column via lookup table

BEGIN TRANSACTION;

-- Import format type classification lookup table
DROP TABLE IF EXISTS format_type_classification;
CREATE TABLE format_type_classification AS
SELECT
    format_type AS FormatType,
    is_oer::BOOLEAN AS is_oer,
    oer_category,
    is_ia::BOOLEAN AS is_ia,
    ia_category
FROM read_csv('${LOOKUP_DIR}/format_type_lookup.tsv',
    delim='\t',
    header=true,
    columns={
        'format_type': 'VARCHAR',
        'is_oer': 'VARCHAR',
        'oer_category': 'VARCHAR',
        'is_ia': 'VARCHAR',
        'ia_category': 'VARCHAR'
    }
);

-- Supply (non-course-material) ISBN classification (#36) is built upstream now, in
-- 1a_supply_classification.sql (moved there for #40 so 1b_section_filter.sql's
-- has_required can be supply-aware). This file only READS supply_isbn_classification
-- (the LEFT JOIN in comprehensive_data below); it no longer rebuilds it.

-- Validate FormatType coverage before processing
-- Check for non-empty FormatTypes that aren't in the lookup table
WITH unmatched AS (
    SELECT c.FormatType, COUNT(*) as record_count
    FROM course_catalog_20251215 c
    LEFT JOIN format_type_classification f ON c.FormatType = f.FormatType
    WHERE c.FormatType IS NOT NULL
      AND c.FormatType != ''
      AND f.FormatType IS NULL
    GROUP BY c.FormatType
)
SELECT
    'WARNING: Unmatched FormatTypes found' AS validation_status,
    COUNT(*) as unmatched_format_count,
    SUM(record_count) as affected_records
FROM unmatched
HAVING COUNT(*) > 0;

-- Add OER, IA, and is_required_inferred fields to comprehensive_data table
-- Note: comprehensive_data was created as a table in 0_setup.sql, so we need to recreate it
DROP TABLE IF EXISTS comprehensive_data;
CREATE TABLE comprehensive_data AS
SELECT
    c.*,
    -- Add OER classification from lookup table (NULL if no match)
    f.is_oer AS is_oer,
    COALESCE(f.oer_category, 'unknown') AS oer_category,
    -- Add IA (Inclusive Access) classification from lookup table (NULL if no match)
    f.is_ia AS is_ia,
    COALESCE(f.ia_category, 'unknown') AS ia_category,
    -- Supply classification (#36): ISBN-level title-keyword flag from
    -- supply_isbn_classification. Never NULL — unmatched (incl. NULL ISBN13) is FALSE.
    (si.isbn13 IS NOT NULL) AS is_supply,
    si.category AS supply_category,
    -- IPEDS data
    i.instnm AS institution_name,
    i.sector AS sector,
    i.iclevel AS level,
    i.control AS control,
    i.instsize AS size,
    i.enroll_24 AS enrollment_2024,
    i.dist_enroll_24 AS distance_enrollment_2024,
    i.inst_type AS institution_type,
    -- Panel data
    p.response_year AS panel_response_year,
    -- Opt-out data
    CASE WHEN oo.email IS NOT NULL THEN true ELSE false END AS is_opted_out,
    'opt_out' AS opt_out_source,
    -- is_required_inferred: period >= 2024 AND book_status matches has_required logic
    CASE
        WHEN c.period_date >= '2024-01-01'
         AND (
             (s.has_required = TRUE  AND c.book_status = 'required')
             OR
             (s.has_required = FALSE AND c.book_status IS NULL)
         )
        THEN TRUE
        ELSE FALSE
    END AS is_required_inferred
FROM course_catalog_20251215 c
LEFT JOIN format_type_classification f ON c.FormatType = f.FormatType
LEFT JOIN supply_isbn_classification si ON c."ISBN13" = si.isbn13
LEFT JOIN ipeds_data i ON c.unit_id = i.unitid
LEFT JOIN panel p ON c.email = p.email
LEFT JOIN opt_out oo ON c.email = oo.email
LEFT JOIN section_book_status s ON c.section_id = s.section_id;

-- Validation: Check distribution of OER/IA classifications including NULLs
SELECT
    'OER/IA Distribution Check' AS validation_status,
    is_oer,
    is_ia,
    COUNT(*) as record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percent
FROM comprehensive_data
GROUP BY is_oer, is_ia
ORDER BY record_count DESC;

-- Validation: supply classification distribution (single-line summary)
SELECT
    'Supply Classification Check' AS validation_status,
    COUNT(*) FILTER (WHERE is_supply) AS supply_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_supply) / COUNT(*), 2) AS pct_of_rows,
    COUNT(DISTINCT "ISBN13") FILTER (WHERE is_supply) AS supply_isbns
FROM comprehensive_data;

-- DQ (#41): required rows carrying a pseudo-SKU ISBN (non-978/979 EAN — internal
-- bookstore codes). A MIX of legitimate non-book materials (access codes, digital
-- bundles) and noise (supplies/placeholders the title classifier missed) — needs a
-- precision audit before acting on it. The #40 fix's blank-status fallback can promote
-- a small slice of the noise. Real book ISBNs are 978/979-prefixed; NULL-ISBN required
-- rows are legitimate (book adopted, ISBN not entered) and excluded here.
SELECT 'Required rows without a standard book ISBN (#41 audit)' AS validation_status,
       COUNT(*) AS pseudo_required_rows,
       COUNT(DISTINCT "ISBN13") AS pseudo_required_isbns
FROM comprehensive_data
WHERE is_required_inferred AND NOT is_supply
  AND "ISBN13" IS NOT NULL
  AND NOT ("ISBN13" BETWEEN 9780000000000 AND 9799999999999);

COMMIT;
