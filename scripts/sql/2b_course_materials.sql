-- Canonical processed Course Materials and section enrollment ownership.
--
-- comprehensive_data remains the enriched source-row table. course_materials
-- is the first item-grain model: one row per valid period/section/ISBN, plus
-- one NULL-ISBN audit row per period/section when such source rows exist.

${CONFIG}

DROP VIEW IF EXISTS course_materials_canada;
DROP VIEW IF EXISTS course_materials_no_use;
DROP VIEW IF EXISTS course_materials_use;
DROP VIEW IF EXISTS course_materials_post_2024;

DROP TABLE IF EXISTS _se_base;
DROP TABLE IF EXISTS _se_course_level;
DROP TABLE IF EXISTS _se_signals;
DROP TABLE IF EXISTS _se_enriched;
DROP TABLE IF EXISTS _se_reference;
DROP TABLE IF EXISTS _se_course_agg;
DROP TABLE IF EXISTS _se_class_agg;
DROP TABLE IF EXISTS _se_level_agg;
DROP TABLE IF EXISTS _cm_key_agg;
DROP TABLE IF EXISTS _cm_section_isbn;
DROP TABLE IF EXISTS _cm_duplicate_representative;
DROP TABLE IF EXISTS _cm_duplicate_variants;
DROP TABLE IF EXISTS _cm_isbn_metadata;

DROP TABLE IF EXISTS section_enrollment;
DROP TABLE IF EXISTS course_materials;

-- Complete valid 2024+ section spine and the established assignment ladder:
-- own enrollment, own valid seats, course medians, control/level median, then
-- level median. This remains independent of material inclusion.
CREATE TEMP TABLE _se_base AS
SELECT
    section_id,
    ANY_VALUE(course_id) AS course_id,
    ANY_VALUE(period_sortable) AS period_sortable,
    ANY_VALUE(control) AS control,
    ANY_VALUE(level) AS level,
    ANY_VALUE(sector) AS sector,
    MAX(enrollments) AS enrollments,
    MAX(seats_taken) AS seats_taken,
    (MAX(enrollments) IS NOT NULL) AS has_enrollment,
    (MAX(seats_taken) IS NOT NULL AND MAX(seats_taken) < 9999)
        AS has_enrollment_own_seats
FROM comprehensive_data
WHERE section_id IS NOT NULL
  AND period_sortable IS NOT NULL
  AND period_date >= DATE '2024-01-01'
GROUP BY section_id;

-- Input order is not a contract. Resolve equally frequent source labels
-- lexically so panel/join plan changes cannot alter canonical metadata.
CREATE TEMP TABLE _se_course_level AS
SELECT section_id, mode(course_level ORDER BY course_level) AS course_level
FROM comprehensive_data
WHERE section_id IS NOT NULL
  AND period_sortable IS NOT NULL
  AND period_date >= DATE '2024-01-01'
GROUP BY section_id;

CREATE TEMP TABLE _se_signals AS
SELECT
    course_id,
    period_sortable,
    SUM(CASE WHEN has_enrollment THEN 1 ELSE 0 END) AS course_enroll_sections,
    SUM(CASE WHEN has_enrollment_own_seats THEN 1 ELSE 0 END) AS course_seats_sections
FROM _se_base
GROUP BY course_id, period_sortable;

CREATE TEMP TABLE _se_enriched AS
SELECT
    b.*,
    cl.course_level,
    ((s.course_enroll_sections - CASE WHEN b.has_enrollment THEN 1 ELSE 0 END) > 0)
        AS has_enrollment_sibling,
    ((s.course_seats_sections - CASE WHEN b.has_enrollment_own_seats THEN 1 ELSE 0 END) > 0)
        AS has_enrollment_sibling_seats
FROM _se_base b
JOIN _se_course_level cl USING (section_id)
JOIN _se_signals s
  ON b.course_id IS NOT DISTINCT FROM s.course_id
 AND b.period_sortable IS NOT DISTINCT FROM s.period_sortable;

DROP TABLE _se_base;
DROP TABLE _se_course_level;
DROP TABLE _se_signals;

CREATE TEMP TABLE _se_reference AS
SELECT course_id, period_sortable, control, level, enrollments, seats_taken
FROM _se_enriched
WHERE course_level IN ('Introductory or general undergraduate', 'Intermediate undergraduate',
                       'Non-degree credit', 'Uncategorized')
  AND sector IN ('Public, 4-year or above', 'Public, 2-year',
                 'Private not-for-profit, 4-year or above', 'Private not-for-profit, 2-year',
                 'Private for-profit, 4-year or above', 'Private for-profit, 2-year');

CREATE TEMP TABLE _se_course_agg AS
SELECT
    course_id,
    period_sortable,
    quantile_cont(enrollments, 0.5) AS course_enrollment_median,
    quantile_cont(CASE WHEN seats_taken < 9999 THEN seats_taken END, 0.5)
        AS course_seats_median
FROM _se_reference
GROUP BY course_id, period_sortable;

CREATE TEMP TABLE _se_class_agg AS
SELECT
    control,
    level,
    period_sortable,
    quantile_cont(enrollments, 0.5) AS class_enrollment_median
FROM _se_reference
GROUP BY control, level, period_sortable;

CREATE TEMP TABLE _se_level_agg AS
SELECT
    level,
    period_sortable,
    quantile_cont(enrollments, 0.5) AS level_enrollment_median
FROM _se_reference
GROUP BY level, period_sortable;

DROP TABLE _se_reference;

CREATE TABLE section_enrollment AS
SELECT
    base.section_id,
    base.course_id,
    base.period_sortable,
    base.control,
    base.level,
    base.sector,
    base.course_level,
    base.enrollments,
    base.seats_taken,
    base.has_enrollment,
    base.has_enrollment_sibling,
    base.has_enrollment_own_seats,
    base.has_enrollment_sibling_seats,
    ROUND(COALESCE(base.enrollments,
                   CASE WHEN base.seats_taken < 9999 THEN base.seats_taken END,
                   ca.course_enrollment_median,
                   ca.course_seats_median,
                   cla.class_enrollment_median,
                   lv.level_enrollment_median))::INT AS enrollment_assigned,
    CASE
        WHEN base.enrollments IS NOT NULL             THEN 'own'
        WHEN base.seats_taken < 9999                  THEN 'own_seats'
        WHEN ca.course_enrollment_median IS NOT NULL  THEN 'sibling_enroll'
        WHEN ca.course_seats_median IS NOT NULL       THEN 'sibling_seats'
        WHEN cla.class_enrollment_median IS NOT NULL  THEN 'class_median'
        WHEN lv.level_enrollment_median IS NOT NULL   THEN 'level_median'
        ELSE 'none'
    END AS enrollment_source
FROM _se_enriched base
LEFT JOIN _se_course_agg ca
  ON base.course_id = ca.course_id
 AND base.period_sortable = ca.period_sortable
LEFT JOIN _se_class_agg cla
  ON base.control = cla.control
 AND base.level = cla.level
 AND base.period_sortable = cla.period_sortable
LEFT JOIN _se_level_agg lv
  ON base.level = lv.level
 AND base.period_sortable = lv.period_sortable;

DROP TABLE _se_enriched;
DROP TABLE _se_course_agg;
DROP TABLE _se_class_agg;
DROP TABLE _se_level_agg;

-- Fixed-size aggregate state is safe for every high-cardinality item key.
-- Expensive DISTINCT metadata state and representative windows are restricted
-- below to keys that actually have multiple source rows.
CREATE TEMP TABLE _cm_key_agg AS
SELECT
    period_sortable,
    section_id,
    "ISBN13" AS isbn13,
    COUNT(*) AS source_row_count,
    COUNT(*) FILTER (WHERE is_course_material_use) AS use_source_row_count,
    COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_source_row_count,
    BOOL_OR(is_post_2024) AS is_post_2024,
    BOOL_OR(is_course_material_use) AS has_use_source_row,
    BOOL_OR(is_course_material_no_use) AS has_no_use_source_row,
    BOOL_OR(is_required_inferred) AS is_required_inferred,
    BOOL_OR(is_oer) AS is_oer,
    BOOL_OR(is_ia) AS is_ia,
    BOOL_OR(is_supply) AS is_supply,
    BOOL_OR(has_formattype) AS has_formattype,
    BOOL_OR(no_details) AS no_details,
    BOOL_OR(no_materials) AS no_materials,
    BOOL_OR(is_canada) AS is_canada,
    BOOL_OR(book_status = 'required') AS has_book_status_required,
    BOOL_OR(book_status IN ('option', 'recommended'))
        AS has_book_status_optional_recommended,
    BOOL_OR(is_required_inferred) IS DISTINCT FROM BOOL_AND(is_required_inferred)
        AS is_required_inferred_conflict,
    BOOL_OR(is_oer) IS DISTINCT FROM BOOL_AND(is_oer) AS is_oer_conflict,
    BOOL_OR(is_ia) IS DISTINCT FROM BOOL_AND(is_ia) AS is_ia_conflict,
    BOOL_OR(is_supply) IS DISTINCT FROM BOOL_AND(is_supply) AS is_supply_conflict,
    BOOL_OR(no_details) IS DISTINCT FROM BOOL_AND(no_details) AS no_details_conflict,
    BOOL_OR(no_materials) IS DISTINCT FROM BOOL_AND(no_materials) AS no_materials_conflict,
    BOOL_OR(is_canada) IS DISTINCT FROM BOOL_AND(is_canada) AS is_canada_conflict
FROM comprehensive_data
WHERE period_sortable IS NOT NULL
  AND section_id IS NOT NULL
GROUP BY period_sortable, section_id, "ISBN13";

CREATE TEMP TABLE _cm_section_isbn AS
SELECT
    period_sortable,
    section_id,
    BOOL_OR(isbn13 IS NOT NULL) AS has_nonnull_isbn_in_section
FROM _cm_key_agg
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _cm_duplicate_representative AS
SELECT * EXCLUDE (representative_rank)
FROM (
    SELECT
        c.*,
        ROW_NUMBER() OVER (
            PARTITION BY c.period_sortable, c.section_id, c."ISBN13"
            ORDER BY
                c.is_course_material_use DESC,
                c.is_required_inferred DESC,
                c.book_status NULLS LAST,
                c."Title" NULLS LAST,
                c."Author" NULLS LAST,
                c."Publisher" NULLS LAST,
                c."FormatType" NULLS LAST,
                c.is_oer NULLS LAST,
                c.is_ia NULLS LAST,
                c.is_supply NULLS LAST,
                c.unit_id NULLS LAST,
                c.institution_name NULLS LAST,
                c.state NULLS LAST,
                c.control NULLS LAST,
                c.level NULLS LAST,
                c.size NULLS LAST,
                c.sector NULLS LAST,
                c.institution_type NULLS LAST,
                c.enrollment_2024 NULLS LAST,
                c.distance_enrollment_2024 NULLS LAST,
                c.course_id NULLS LAST,
                c.course_title NULLS LAST,
                c.course_subject NULLS LAST,
                c.course_level NULLS LAST,
                c.department NULLS LAST,
                c.course_number NULLS LAST,
                c.section NULLS LAST,
                c.period NULLS LAST,
                c.enrollments NULLS LAST,
                c.seats_taken NULLS LAST,
                c.instructor NULLS LAST,
                c.first_name NULLS LAST,
                c.last_name NULLS LAST,
                c.email NULLS LAST,
                c."Imprint" NULLS LAST,
                c."Format" NULLS LAST,
                c.school NULLS LAST,
                c.dept_code NULLS LAST,
                c.dept_description NULLS LAST,
                c.period_date NULLS LAST,
                c.oer_category NULLS LAST,
                c.ia_category NULLS LAST,
                c.supply_category NULLS LAST,
                c.panel_response_year NULLS LAST,
                c.panel_source_row_count NULLS LAST,
                c.panel_response_year_variant_count NULLS LAST,
                c.is_opted_out NULLS LAST,
                c.opt_out_source NULLS LAST
        ) AS representative_rank
    FROM comprehensive_data c
    JOIN _cm_key_agg k
      ON c.period_sortable = k.period_sortable
     AND c.section_id = k.section_id
     AND c."ISBN13" IS NOT DISTINCT FROM k.isbn13
    WHERE k.source_row_count > 1
) ranked
WHERE representative_rank = 1;

CREATE TEMP TABLE _cm_duplicate_variants AS
SELECT
    c.period_sortable,
    c.section_id,
    c."ISBN13" AS isbn13,
    COUNT(DISTINCT NULLIF(TRIM(c."Title"), '')) AS title_variant_count,
    COUNT(DISTINCT NULLIF(TRIM(c."Author"), '')) AS author_variant_count,
    COUNT(DISTINCT NULLIF(TRIM(c."Publisher"), '')) AS publisher_variant_count,
    COUNT(DISTINCT NULLIF(TRIM(c."Imprint"), '')) AS imprint_variant_count,
    COUNT(DISTINCT NULLIF(TRIM(c."Format"), '')) AS book_format_variant_count,
    COUNT(DISTINCT NULLIF(TRIM(c."FormatType"), '')) AS format_type_variant_count,
    COUNT(DISTINCT NULLIF(TRIM(c.book_status), '')) AS book_status_variant_count,
    COUNT(DISTINCT NULLIF(TRIM(c.instructor), '')) AS instructor_variant_count,
    COUNT(DISTINCT NULLIF(TRIM(c.email), '')) AS email_variant_count
FROM comprehensive_data c
JOIN _cm_key_agg k
  ON c.period_sortable = k.period_sortable
 AND c.section_id = k.section_id
 AND c."ISBN13" IS NOT DISTINCT FROM k.isbn13
WHERE k.source_row_count > 1
GROUP BY c.period_sortable, c.section_id, c."ISBN13";

-- Term/ISBN compatibility metadata belongs upstream of costs so Master ISBN and
-- every release-facing material field can flow through canonical Course Materials.
CREATE TEMP TABLE _cm_isbn_metadata AS
SELECT
    period_sortable,
    "ISBN13" AS isbn13,
    MIN(NULLIF(TRIM("Title"), '')) AS isbn_book_title,
    MIN(NULLIF(TRIM("Author"), '')) AS isbn_author,
    MIN(NULLIF(TRIM("Publisher"), '')) AS isbn_publisher,
    COUNT(DISTINCT NULLIF(TRIM("Title"), '')) AS isbn_title_variant_count,
    COUNT(DISTINCT NULLIF(TRIM("Author"), '')) AS isbn_author_variant_count,
    COUNT(DISTINCT NULLIF(TRIM("Publisher"), '')) AS isbn_publisher_variant_count
FROM comprehensive_data
WHERE is_course_material_use
  AND period_sortable IS NOT NULL
  AND section_id IS NOT NULL
  AND "ISBN13" IS NOT NULL
GROUP BY period_sortable, "ISBN13";

CREATE TABLE course_materials AS
WITH representative AS (
    -- Unique item groups can stream directly from the enriched source table;
    -- only duplicate groups require a materialized representative window.
    SELECT c.*
    FROM comprehensive_data c
    JOIN _cm_key_agg k
      ON c.period_sortable = k.period_sortable
     AND c.section_id = k.section_id
     AND c."ISBN13" IS NOT DISTINCT FROM k.isbn13
    WHERE k.source_row_count = 1
    UNION ALL
    SELECT * FROM _cm_duplicate_representative
)
SELECT
    a.isbn13::BIGINT AS isbn13,
    r."Title" AS book_title,
    r."Author" AS author,
    r."Publisher" AS publisher,
    r."Imprint" AS imprint,
    r."Format" AS book_format,
    r."FormatType" AS format_type,
    r.book_status,
    im.isbn_book_title,
    im.isbn_author,
    im.isbn_publisher,
    im.isbn_title_variant_count,
    im.isbn_author_variant_count,
    im.isbn_publisher_variant_count,
    r.unit_id,
    r.school,
    r.state,
    r.dept_code,
    r.department,
    r.dept_description,
    r.course_number,
    r.section,
    r.course_title,
    COALESCE(se.course_level, r.course_level) AS course_level,
    r.course_subject,
    r.period,
    COALESCE(se.enrollments, r.enrollments) AS enrollments,
    COALESCE(se.seats_taken, r.seats_taken) AS seats_taken,
    r.instructor,
    r.first_name,
    r.last_name,
    r.email,
    COALESCE(se.course_id, r.course_id) AS course_id,
    r.section_id,
    r.period_sortable,
    r.period_date,
    a.is_oer,
    r.oer_category,
    a.is_ia,
    r.ia_category,
    a.is_supply,
    r.supply_category,
    r.institution_name,
    COALESCE(se.sector, r.sector) AS sector,
    COALESCE(se.level, r.level) AS level,
    COALESCE(se.control, r.control) AS control,
    r.size,
    r.enrollment_2024,
    r.distance_enrollment_2024,
    r.institution_type,
    r.panel_response_year,
    r.panel_source_row_count,
    r.panel_response_year_variant_count,
    r.is_opted_out,
    r.opt_out_source,
    a.is_required_inferred,
    a.is_post_2024,
    (a.isbn13 IS NOT NULL) AS has_isbn,
    a.has_formattype,
    COALESCE(se.has_enrollment, r.has_enrollment) AS has_enrollment,
    COALESCE(se.has_enrollment_own_seats, r.has_enrollment_own_seats)
        AS has_enrollment_own_seats,
    a.no_details,
    a.no_materials,
    a.is_canada,
    a.has_use_source_row AS is_course_material_use,
    (a.is_post_2024 AND NOT a.has_use_source_row) AS is_course_material_no_use,
    se.has_enrollment_sibling,
    se.has_enrollment_sibling_seats,
    se.enrollment_assigned,
    se.enrollment_source,
    a.has_book_status_required,
    a.has_book_status_optional_recommended,
    a.source_row_count,
    COALESCE(v.title_variant_count,
             CASE WHEN NULLIF(TRIM(r."Title"), '') IS NULL THEN 0 ELSE 1 END)
        AS title_variant_count,
    COALESCE(v.author_variant_count,
             CASE WHEN NULLIF(TRIM(r."Author"), '') IS NULL THEN 0 ELSE 1 END)
        AS author_variant_count,
    COALESCE(v.publisher_variant_count,
             CASE WHEN NULLIF(TRIM(r."Publisher"), '') IS NULL THEN 0 ELSE 1 END)
        AS publisher_variant_count,
    COALESCE(v.imprint_variant_count,
             CASE WHEN NULLIF(TRIM(r."Imprint"), '') IS NULL THEN 0 ELSE 1 END)
        AS imprint_variant_count,
    COALESCE(v.book_format_variant_count,
             CASE WHEN NULLIF(TRIM(r."Format"), '') IS NULL THEN 0 ELSE 1 END)
        AS book_format_variant_count,
    COALESCE(v.format_type_variant_count,
             CASE WHEN NULLIF(TRIM(r."FormatType"), '') IS NULL THEN 0 ELSE 1 END)
        AS format_type_variant_count,
    COALESCE(v.book_status_variant_count,
             CASE WHEN NULLIF(TRIM(r.book_status), '') IS NULL THEN 0 ELSE 1 END)
        AS book_status_variant_count,
    (COALESCE(v.title_variant_count,
              CASE WHEN NULLIF(TRIM(r."Title"), '') IS NULL THEN 0 ELSE 1 END) > 1
      OR COALESCE(v.author_variant_count,
                  CASE WHEN NULLIF(TRIM(r."Author"), '') IS NULL THEN 0 ELSE 1 END) > 1
      OR COALESCE(v.publisher_variant_count,
                  CASE WHEN NULLIF(TRIM(r."Publisher"), '') IS NULL THEN 0 ELSE 1 END) > 1
      OR COALESCE(v.imprint_variant_count,
                  CASE WHEN NULLIF(TRIM(r."Imprint"), '') IS NULL THEN 0 ELSE 1 END) > 1
      OR COALESCE(v.book_format_variant_count,
                  CASE WHEN NULLIF(TRIM(r."Format"), '') IS NULL THEN 0 ELSE 1 END) > 1
      OR COALESCE(v.format_type_variant_count,
                  CASE WHEN NULLIF(TRIM(r."FormatType"), '') IS NULL THEN 0 ELSE 1 END) > 1
      OR COALESCE(v.book_status_variant_count,
                  CASE WHEN NULLIF(TRIM(r.book_status), '') IS NULL THEN 0 ELSE 1 END) > 1)
        AS catalog_metadata_conflict,
    a.is_required_inferred_conflict,
    a.is_oer_conflict,
    a.is_ia_conflict,
    a.use_source_row_count,
    a.no_use_source_row_count,
    a.has_use_source_row,
    a.has_no_use_source_row,
    (a.use_source_row_count > 0 AND a.no_use_source_row_count > 0)
        AS population_classification_conflict,
    COALESCE(v.instructor_variant_count,
             CASE WHEN NULLIF(TRIM(r.instructor), '') IS NULL THEN 0 ELSE 1 END)
        AS instructor_variant_count,
    COALESCE(v.email_variant_count,
             CASE WHEN NULLIF(TRIM(r.email), '') IS NULL THEN 0 ELSE 1 END)
        AS email_variant_count,
    (COALESCE(v.instructor_variant_count,
              CASE WHEN NULLIF(TRIM(r.instructor), '') IS NULL THEN 0 ELSE 1 END) > 1
      OR COALESCE(v.email_variant_count,
                  CASE WHEN NULLIF(TRIM(r.email), '') IS NULL THEN 0 ELSE 1 END) > 1)
        AS contact_metadata_conflict,
    a.is_supply_conflict,
    a.no_details_conflict,
    a.no_materials_conflict,
    a.is_canada_conflict,
    (a.isbn13 IS NULL) AS is_null_isbn_audit,
    si.has_nonnull_isbn_in_section,
    (a.isbn13 IS NULL AND NOT si.has_nonnull_isbn_in_section)
        AS is_no_adoption_section
FROM representative r
JOIN _cm_key_agg a
  ON r.period_sortable = a.period_sortable
 AND r.section_id = a.section_id
 AND r."ISBN13" IS NOT DISTINCT FROM a.isbn13
JOIN _cm_section_isbn si
  ON a.period_sortable = si.period_sortable
 AND a.section_id = si.section_id
LEFT JOIN _cm_duplicate_variants v
  ON a.period_sortable = v.period_sortable
 AND a.section_id = v.section_id
 AND a.isbn13 IS NOT DISTINCT FROM v.isbn13
LEFT JOIN section_enrollment se
  ON r.period_sortable = se.period_sortable
 AND r.section_id = se.section_id
LEFT JOIN _cm_isbn_metadata im
  ON r.period_sortable = im.period_sortable
 AND a.isbn13 = im.isbn13;

DROP TABLE _cm_key_agg;
DROP TABLE _cm_section_isbn;
DROP TABLE _cm_duplicate_representative;
DROP TABLE _cm_duplicate_variants;
DROP TABLE _cm_isbn_metadata;

CREATE VIEW course_materials_post_2024 AS
SELECT * FROM course_materials WHERE is_post_2024;

CREATE VIEW course_materials_use AS
SELECT * FROM course_materials WHERE is_course_material_use;

CREATE VIEW course_materials_no_use AS
SELECT * FROM course_materials WHERE is_course_material_no_use;

CREATE VIEW course_materials_canada AS
SELECT *
FROM course_materials
WHERE is_course_material_no_use AND is_canada;

-- Raw rows with invalid canonical keys remain preserved and explicitly reported.
SELECT
    'Course Materials invalid raw keys' AS metric,
    COUNT(*) FILTER (WHERE period_sortable IS NULL) AS null_period_rows,
    COUNT(*) FILTER (WHERE section_id IS NULL) AS null_section_rows,
    COUNT(*) FILTER (WHERE period_sortable IS NULL OR section_id IS NULL)
        AS excluded_invalid_key_rows
FROM comprehensive_data;

SELECT
    'Course Materials raw-to-canonical conservation' AS metric,
    (SELECT COUNT(*) FROM comprehensive_data
      WHERE period_sortable IS NOT NULL AND section_id IS NOT NULL) AS valid_raw_rows,
    (SELECT SUM(source_row_count) FROM course_materials) AS represented_raw_rows,
    (SELECT COUNT(*) FROM comprehensive_data
      WHERE period_sortable IS NOT NULL AND section_id IS NOT NULL)
      - (SELECT SUM(source_row_count) FROM course_materials) AS row_difference;

SELECT
    'Course Materials grain and NULL audit' AS metric,
    COUNT(*) AS rows,
    COUNT(*) FILTER (WHERE isbn13 IS NOT NULL)
      - COUNT(DISTINCT (period_sortable, section_id, isbn13))
          FILTER (WHERE isbn13 IS NOT NULL) AS duplicate_nonnull_key_rows,
    COUNT(*) FILTER (WHERE isbn13 IS NULL)
      - COUNT(DISTINCT (period_sortable, section_id))
          FILTER (WHERE isbn13 IS NULL) AS duplicate_null_audit_rows,
    COUNT(*) FILTER (WHERE period_sortable IS NULL OR section_id IS NULL)
        AS invalid_key_rows,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_null_isbn_audit), 0)
      - (SELECT COUNT(*) FROM comprehensive_data
         WHERE period_sortable IS NOT NULL
           AND section_id IS NOT NULL
           AND "ISBN13" IS NULL) AS null_source_row_difference,
    COUNT(*) FILTER (
        WHERE is_no_adoption_section IS DISTINCT FROM
              (is_null_isbn_audit AND NOT has_nonnull_isbn_in_section)
    ) AS no_adoption_flag_violations
FROM course_materials;

SELECT
    'Course Materials population contract' AS metric,
    COUNT(*) FILTER (
        WHERE is_post_2024
          AND is_course_material_use = is_course_material_no_use
    ) AS post_2024_partition_violations,
    COUNT(*) FILTER (
        WHERE NOT is_post_2024
          AND (is_course_material_use OR is_course_material_no_use)
    ) AS pre_2024_flag_violations,
    COUNT(*) FILTER (
        WHERE source_row_count <> use_source_row_count + no_use_source_row_count
          AND is_post_2024
    ) AS post_2024_source_count_violations,
    COUNT(*) FILTER (
        WHERE population_classification_conflict IS DISTINCT FROM
              (use_source_row_count > 0 AND no_use_source_row_count > 0)
    ) AS population_conflict_flag_violations,
    COUNT(*) FILTER (WHERE is_null_isbn_audit AND is_course_material_use)
        AS null_isbn_use_violations
FROM course_materials;

WITH raw_use_keys AS (
    SELECT period_sortable, section_id, "ISBN13" AS isbn13
    FROM comprehensive_data
    WHERE is_course_material_use
      AND period_sortable IS NOT NULL
      AND section_id IS NOT NULL
      AND "ISBN13" IS NOT NULL
    GROUP BY period_sortable, section_id, "ISBN13"
)
SELECT
    'Course Materials raw Use key conservation' AS metric,
    (SELECT COUNT(*) FROM raw_use_keys) AS raw_distinct_use_keys,
    (SELECT COUNT(*) FROM course_materials_use) AS canonical_use_rows,
    (SELECT COUNT(*) FROM raw_use_keys)
      - (SELECT COUNT(*) FROM course_materials_use) AS key_count_difference;

WITH flag_counts AS (
    SELECT
        COUNT(*) FILTER (WHERE is_post_2024) AS post_2024_rows,
        COUNT(*) FILTER (WHERE is_course_material_use) AS use_rows,
        COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_rows,
        COUNT(*) FILTER (WHERE is_course_material_no_use AND is_canada) AS canada_rows
    FROM course_materials
), view_counts AS (
    SELECT
        (SELECT COUNT(*) FROM course_materials_post_2024) AS post_2024_rows,
        (SELECT COUNT(*) FROM course_materials_use) AS use_rows,
        (SELECT COUNT(*) FROM course_materials_no_use) AS no_use_rows,
        (SELECT COUNT(*) FROM course_materials_canada) AS canada_rows
)
SELECT
    'Course Materials population view conservation' AS metric,
    ABS(v.post_2024_rows - f.post_2024_rows) AS post_2024_violations,
    ABS(v.use_rows - f.use_rows) AS use_violations,
    ABS(v.no_use_rows - f.no_use_rows) AS no_use_violations,
    ABS(v.canada_rows - f.canada_rows) AS canada_violations
FROM flag_counts f
CROSS JOIN view_counts v;

SELECT
    'section_enrollment grain/key DQ' AS metric,
    COUNT(*) AS rows,
    COUNT(*) - COUNT(DISTINCT section_id) AS duplicate_rows,
    COUNT(*) FILTER (WHERE section_id IS NULL OR period_sortable IS NULL) AS key_null_rows,
    COUNT(*) FILTER (
        WHERE has_enrollment IS DISTINCT FROM (enrollments IS NOT NULL)
           OR has_enrollment_own_seats IS DISTINCT FROM
              (seats_taken IS NOT NULL AND seats_taken < 9999)
    ) AS raw_flag_violations,
    COUNT(*) FILTER (WHERE (enrollment_assigned IS NULL) <> (enrollment_source = 'none'))
        AS assignment_source_violations
FROM section_enrollment;

ANALYZE section_enrollment;
ANALYZE course_materials;
