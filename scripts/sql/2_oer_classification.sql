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

-- Add OER, IA, population-contract, and is_required_inferred fields to
-- comprehensive_data.  The row flags are authoritative: downstream material
-- models filter is_course_material_use instead of rebuilding the exclusions.
-- Note: comprehensive_data was created as a table in 0_setup.sql, so we need to recreate it
DROP VIEW IF EXISTS course_materials_canada;
DROP VIEW IF EXISTS course_materials_no_use;
DROP VIEW IF EXISTS course_materials_use;
DROP VIEW IF EXISTS course_materials_post_2024;
DROP TABLE IF EXISTS comprehensive_data;
CREATE TABLE comprehensive_data AS
WITH joined AS (
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
LEFT JOIN section_book_status s ON c.section_id = s.section_id
),
row_flags AS (
    SELECT
        joined.*,
        COALESCE(period_date >= DATE '2024-01-01', FALSE) AS is_post_2024,
        ("ISBN13" IS NOT NULL) AS has_isbn,
        ("FormatType" IS NOT NULL AND TRIM("FormatType") <> '') AS has_formattype,
        (enrollments IS NOT NULL) AS has_enrollment,
        (seats_taken IS NOT NULL AND seats_taken < 9999) AS has_enrollment_own_seats,
        COALESCE("Title" = '*No Book Details*', FALSE) AS no_details,
        (COALESCE("Title" = '*No Books Required*', FALSE)
            OR COALESCE(supply_category = 'placeholder_no_material', FALSE)) AS no_materials,
        COALESCE(state = 'CAN', FALSE) AS is_canada
    FROM joined
)
SELECT
    row_flags.*,
    (
        is_post_2024
        AND NOT is_canada
        AND has_isbn
        AND NOT is_supply
        AND NOT no_details
        AND NOT no_materials
    ) AS is_course_material_use,
    (
        is_post_2024
        AND NOT (
            NOT is_canada
            AND has_isbn
            AND NOT is_supply
            AND NOT no_details
            AND NOT no_materials
        )
    ) AS is_course_material_no_use
FROM row_flags;

-- Stable population views for releases and downstream ad-hoc analysis. Canada is
-- a post-2024 subset and is also part of NoUse; the sets intentionally overlap.
CREATE VIEW course_materials_post_2024 AS
SELECT * FROM comprehensive_data WHERE is_post_2024;

CREATE VIEW course_materials_use AS
SELECT * FROM comprehensive_data WHERE is_course_material_use;

CREATE VIEW course_materials_no_use AS
SELECT * FROM comprehensive_data WHERE is_course_material_no_use;

CREATE VIEW course_materials_canada AS
SELECT * FROM comprehensive_data WHERE is_post_2024 AND is_canada;

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

-- Population contract DQ. Exactly one of Use/NoUse is true for every post-2024
-- row; neither is true before 2024. Exclusion booleans deliberately remain
-- independent because (for example) a row can be both Canadian and no-material.
SELECT
    'Course-material population contract' AS validation_status,
    COUNT(*) FILTER (WHERE is_post_2024) AS post_2024_rows,
    COUNT(*) FILTER (WHERE is_course_material_use) AS use_rows,
    COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_rows,
    COUNT(*) FILTER (
        WHERE is_post_2024
          AND is_course_material_use = is_course_material_no_use
    ) AS post_2024_partition_violations,
    COUNT(*) FILTER (
        WHERE NOT is_post_2024
          AND (is_course_material_use OR is_course_material_no_use)
    ) AS pre_2024_flag_violations,
    COUNT(*) FILTER (
        WHERE is_post_2024 AND is_canada AND NOT is_course_material_no_use
    ) AS canada_not_no_use_violations,
    COUNT(*) FILTER (WHERE is_post_2024)
      - COUNT(*) FILTER (WHERE is_course_material_use)
      - COUNT(*) FILTER (WHERE is_course_material_no_use) AS partition_difference
FROM comprehensive_data;

SELECT
    'Course-material population contract by term' AS validation_status,
    period_sortable,
    COUNT(*) AS post_2024_rows,
    COUNT(*) FILTER (WHERE is_course_material_use) AS use_rows,
    COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_rows,
    COUNT(*) FILTER (WHERE NOT has_isbn) AS no_isbn_rows,
    COUNT(*) FILTER (WHERE is_supply) AS supply_rows,
    COUNT(*) FILTER (WHERE no_details) AS no_details_rows,
    COUNT(*) FILTER (WHERE no_materials) AS no_materials_rows,
    COUNT(*) FILTER (
        WHERE is_course_material_use = is_course_material_no_use
    ) AS partition_violations,
    COUNT(*) FILTER (WHERE is_canada) AS canada_rows,
    COUNT(*) FILTER (WHERE is_canada AND NOT is_course_material_no_use)
        AS canada_not_no_use_violations
FROM comprehensive_data
WHERE is_post_2024
GROUP BY period_sortable
ORDER BY period_sortable;

-- Preserve the overlap structure rather than forcing one exclusion-reason
-- precedence. Cardinality 0 is exactly Use; cardinality >= 1 is exactly NoUse.
WITH reason_cardinality AS (
    SELECT
        period_sortable,
        CAST(is_canada AS INTEGER)
          + CAST(NOT has_isbn AS INTEGER)
          + CAST(is_supply AS INTEGER)
          + CAST(no_details AS INTEGER)
          + CAST(no_materials AS INTEGER) AS no_use_reason_count
    FROM comprehensive_data
    WHERE is_post_2024
)
SELECT
    'Course-material NoUse reason cardinality' AS validation_status,
    period_sortable,
    no_use_reason_count,
    COUNT(*) AS record_count
FROM reason_cardinality
GROUP BY period_sortable, no_use_reason_count
ORDER BY period_sortable, no_use_reason_count;

-- Exact observed combinations make every overlap auditable without storing a
-- lossy single reason on comprehensive_data.
SELECT
    'Course-material NoUse reason combinations' AS validation_status,
    period_sortable,
    is_canada,
    NOT has_isbn AS no_isbn,
    is_supply,
    no_details,
    no_materials,
    COUNT(*) AS record_count
FROM comprehensive_data
WHERE is_post_2024
GROUP BY period_sortable, is_canada, has_isbn, is_supply, no_details, no_materials
ORDER BY period_sortable, record_count DESC;

-- The stable views must remain direct projections of their owning booleans.
WITH flag_counts AS (
    SELECT
        COUNT(*) FILTER (WHERE is_post_2024) AS post_2024_rows,
        COUNT(*) FILTER (WHERE is_course_material_use) AS use_rows,
        COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_rows,
        COUNT(*) FILTER (WHERE is_post_2024 AND is_canada) AS canada_rows
    FROM comprehensive_data
), view_counts AS (
    SELECT
        (SELECT COUNT(*) FROM course_materials_post_2024) AS post_2024_rows,
        (SELECT COUNT(*) FROM course_materials_use) AS use_rows,
        (SELECT COUNT(*) FROM course_materials_no_use) AS no_use_rows,
        (SELECT COUNT(*) FROM course_materials_canada) AS canada_rows
)
SELECT
    'Course-material population view conservation' AS validation_status,
    ABS(v.post_2024_rows - f.post_2024_rows) AS post_2024_violations,
    ABS(v.use_rows - f.use_rows) AS use_violations,
    ABS(v.no_use_rows - f.no_use_rows) AS no_use_violations,
    ABS(v.canada_rows - f.canada_rows) AS canada_violations
FROM flag_counts f
CROSS JOIN view_counts v;

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
