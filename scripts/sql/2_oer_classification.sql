-- Add OER (Open Educational Resources) and IA (Inclusive Access) classification
-- Both OER and IA status are derived from FormatType column via lookup table

${CONFIG}

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

-- Supply (non-course-material) ISBN classification (#36) is built upstream in
-- 1a_supply_classification.sql. This file reads it both for row-level supply
-- flags and for the section-level direct-requiredness context below.

-- Validate FormatType coverage before processing
-- Check for non-empty FormatTypes that aren't in the lookup table
WITH unmatched AS (
    SELECT c.FormatType, COUNT(*) as record_count
    FROM ${SURVEY_TABLE} c
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
DROP VIEW IF EXISTS course_materials_canada;
DROP VIEW IF EXISTS course_materials_no_use;
DROP VIEW IF EXISTS course_materials_use;
DROP VIEW IF EXISTS course_materials_post_2024;
DROP VIEW IF EXISTS course_materials_recent;
DROP VIEW IF EXISTS course_material_canada;
DROP VIEW IF EXISTS course_material_no_use;
DROP VIEW IF EXISTS course_material_use;
DROP VIEW IF EXISTS course_material_post_2024;
DROP VIEW IF EXISTS course_material_recent;
DROP TABLE IF EXISTS comprehensive_data;
CREATE TABLE comprehensive_data AS
WITH section_context AS (
    SELECT
        se.*,
        i.control AS section_control,
        i.iclevel AS section_level,
        i.sector AS section_sector
    FROM section_enrollment se
    LEFT JOIN ${IPEDS_TABLE} i ON se.unit_id = i.unitid
), section_reference AS (
    SELECT
        course_id,
        period_sortable,
        section_control,
        section_level,
        enrollments,
        seats_taken
    FROM section_context
    WHERE course_level IN (
        'Introductory or general undergraduate',
        'Intermediate undergraduate',
        'Non-degree credit',
        'Uncategorized'
    )
      AND section_sector IN (
        'Public, 4-year or above',
        'Public, 2-year',
        'Private not-for-profit, 4-year or above',
        'Private not-for-profit, 2-year',
        'Private for-profit, 4-year or above',
        'Private for-profit, 2-year'
    )
), course_medians AS (
    SELECT
        course_id,
        period_sortable,
        quantile_cont(enrollments, 0.5) AS course_enrollment_median,
        quantile_cont(CASE WHEN seats_taken < 9999 THEN seats_taken END, 0.5)
            AS course_seats_median
    FROM section_reference
    GROUP BY course_id, period_sortable
), class_medians AS (
    SELECT
        section_control,
        section_level,
        period_sortable,
        quantile_cont(enrollments, 0.5) AS class_enrollment_median
    FROM section_reference
    GROUP BY section_control, section_level, period_sortable
), level_medians AS (
    SELECT
        section_level,
        period_sortable,
        quantile_cont(enrollments, 0.5) AS level_enrollment_median
    FROM section_reference
    GROUP BY section_level, period_sortable
), section_assignment AS (
    SELECT
        context.*,
        ROUND(COALESCE(
            context.enrollments,
            CASE WHEN context.seats_taken < 9999 THEN context.seats_taken END,
            course.course_enrollment_median,
            course.course_seats_median,
            class.class_enrollment_median,
            level.level_enrollment_median
        ))::INT AS enrollment_assigned,
        CASE
            WHEN context.enrollments IS NOT NULL THEN 'own'
            WHEN context.seats_taken < 9999 THEN 'own_seats'
            WHEN course.course_enrollment_median IS NOT NULL THEN 'sibling_enroll'
            WHEN course.course_seats_median IS NOT NULL THEN 'sibling_seats'
            WHEN class.class_enrollment_median IS NOT NULL THEN 'class_median'
            WHEN level.level_enrollment_median IS NOT NULL THEN 'level_median'
            ELSE 'none'
        END AS enrollment_source
    FROM section_context context
    LEFT JOIN course_medians course
      ON context.course_id = course.course_id
     AND context.period_sortable = course.period_sortable
    LEFT JOIN class_medians class
      ON context.section_control = class.section_control
     AND context.section_level = class.section_level
     AND context.period_sortable = class.period_sortable
    LEFT JOIN level_medians level
      ON context.section_level = level.section_level
     AND context.period_sortable = level.period_sortable
), section_requiredness AS (
    SELECT
        c.period_sortable,
        c.section_id,
        COALESCE(BOOL_OR(c.book_status = 'required' AND si.isbn13 IS NULL), FALSE)
            AS is_section_required_direct
    FROM ${SURVEY_TABLE} c
    LEFT JOIN supply_isbn_classification si ON c."ISBN13" = si.isbn13
    WHERE c.section_id IS NOT NULL
      AND c.period_sortable IS NOT NULL
      AND c.period_sortable IN (SELECT period_sortable FROM recent_period)
    GROUP BY c.period_sortable, c.section_id
), joined AS (
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
    -- Direct requiredness is row-grain; section context comes from the local
    -- requiredness grouping above. Inference uses the shared recent-term window.
    COALESCE(c.book_status = 'required' AND si.isbn13 IS NULL, FALSE) AS is_required_direct,
    sr.is_section_required_direct,
    se.course_id AS section_course_id,
    se.section_control,
    se.section_level,
    se.section_sector,
    se.course_level AS section_course_level,
    se.enrollments AS section_enrollments,
    se.seats_taken AS section_seats_taken,
    se.has_enrollment AS section_has_enrollment,
    se.has_enrollment_own_seats AS section_has_enrollment_own_seats,
    se.has_enrollment_sibling AS section_has_enrollment_sibling,
    se.has_enrollment_sibling_seats AS section_has_enrollment_sibling_seats,
    se.enrollment_assigned AS section_enrollment_assigned,
    se.enrollment_source AS section_enrollment_source,
    CASE
        WHEN c.period_sortable IN (SELECT period_sortable FROM recent_period)
         AND (
             (sr.is_section_required_direct = TRUE  AND c.book_status = 'required')
             OR
             (sr.is_section_required_direct = FALSE AND c.book_status IS NULL)
         )
        THEN TRUE
        ELSE FALSE
    END AS is_required_inferred
FROM ${SURVEY_TABLE} c
LEFT JOIN format_type_classification f ON c.FormatType = f.FormatType
LEFT JOIN supply_isbn_classification si ON c."ISBN13" = si.isbn13
LEFT JOIN ipeds_data i ON c.unit_id = i.unitid
LEFT JOIN section_assignment se
  ON c.period_sortable = se.period_sortable
 AND c.section_id = se.section_id
LEFT JOIN section_requiredness sr
  ON c.period_sortable = sr.period_sortable
 AND c.section_id = sr.section_id
),
row_flags AS (
    SELECT
        joined.*,
        COALESCE(period_sortable IN (SELECT period_sortable FROM recent_period), FALSE) AS is_recent,
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
        is_recent
        AND NOT is_canada
        AND has_isbn
        AND NOT is_supply
        AND NOT no_details
        AND NOT no_materials
    ) AS is_course_material_use,
    (
        is_recent
        AND NOT (
            NOT is_canada
            AND has_isbn
            AND NOT is_supply
            AND NOT no_details
            AND NOT no_materials
        )
    ) AS is_course_material_no_use
FROM row_flags;

-- Every valid section key must receive one stable helper/IPEDS/assignment
-- context before that context is repeated across its catalog material rows.
WITH section_context_dq AS (
    SELECT
        period_sortable,
        section_id,
        MIN(section_course_id) IS DISTINCT FROM MAX(section_course_id)
          OR MIN(section_control) IS DISTINCT FROM MAX(section_control)
          OR MIN(section_level) IS DISTINCT FROM MAX(section_level)
          OR MIN(section_sector) IS DISTINCT FROM MAX(section_sector)
          OR MIN(section_course_level) IS DISTINCT FROM MAX(section_course_level)
          OR MIN(section_enrollments) IS DISTINCT FROM MAX(section_enrollments)
          OR MIN(section_seats_taken) IS DISTINCT FROM MAX(section_seats_taken)
          OR MIN(section_has_enrollment) IS DISTINCT FROM MAX(section_has_enrollment)
          OR MIN(section_has_enrollment_own_seats)
               IS DISTINCT FROM MAX(section_has_enrollment_own_seats)
          OR MIN(section_has_enrollment_sibling)
               IS DISTINCT FROM MAX(section_has_enrollment_sibling)
          OR MIN(section_has_enrollment_sibling_seats)
               IS DISTINCT FROM MAX(section_has_enrollment_sibling_seats)
          OR MIN(section_enrollment_assigned)
               IS DISTINCT FROM MAX(section_enrollment_assigned)
          OR MIN(section_enrollment_source) IS DISTINCT FROM MAX(section_enrollment_source)
            AS has_context_conflict,
        (MIN(section_enrollment_assigned) IS NULL)
          <> (MIN(section_enrollment_source) = 'none') AS assignment_source_violation
    FROM comprehensive_data
    WHERE period_sortable IS NOT NULL
      AND section_id IS NOT NULL
      AND period_sortable IN (SELECT period_sortable FROM recent_period)
    GROUP BY period_sortable, section_id
)
SELECT
    'Section helper/IPEDS assignment context DQ' AS validation_status,
    COUNT(*) AS valid_sections,
    COUNT(*) FILTER (WHERE has_context_conflict) AS context_conflict_sections,
    COUNT(*) FILTER (WHERE assignment_source_violation) AS assignment_source_violations
FROM section_context_dq;

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

-- Population contract DQ. Exactly one of Use/NoUse is true for every recent-term
-- row; neither is true outside the window. Exclusion booleans deliberately remain
-- independent because (for example) a row can be both Canadian and no-material.
SELECT
    'Course-material population contract' AS validation_status,
    COUNT(*) FILTER (WHERE is_recent) AS recent_rows,
    COUNT(*) FILTER (WHERE is_course_material_use) AS use_rows,
    COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_rows,
    COUNT(*) FILTER (
        WHERE is_recent
          AND is_course_material_use = is_course_material_no_use
    ) AS recent_partition_violations,
    COUNT(*) FILTER (
        WHERE NOT is_recent
          AND (is_course_material_use OR is_course_material_no_use)
    ) AS outside_recent_flag_violations,
    COUNT(*) FILTER (
        WHERE is_recent AND is_canada AND NOT is_course_material_no_use
    ) AS canada_not_no_use_violations,
    COUNT(*) FILTER (WHERE is_recent)
      - COUNT(*) FILTER (WHERE is_course_material_use)
      - COUNT(*) FILTER (WHERE is_course_material_no_use) AS partition_difference
FROM comprehensive_data;

SELECT
    'Course-material population contract by term' AS validation_status,
    period_sortable,
    COUNT(*) AS recent_rows,
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
WHERE is_recent
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
    WHERE is_recent
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
WHERE is_recent
GROUP BY period_sortable, is_canada, has_isbn, is_supply, no_details, no_materials
ORDER BY period_sortable, record_count DESC;

-- The enriched raw table must remain exactly one row per normalized catalog
-- source row.
SELECT
    'Raw catalog enrichment one-to-one' AS validation_status,
    (SELECT COUNT(*) FROM ${SURVEY_TABLE}) AS catalog_source_rows,
    (SELECT COUNT(*) FROM comprehensive_data) AS enriched_source_rows,
    (SELECT COUNT(*) FROM comprehensive_data)
      - (SELECT COUNT(*) FROM ${SURVEY_TABLE}) AS row_difference;

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
