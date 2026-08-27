-- Canonical section enrollment and material-cost staging.
--
-- section_enrollment is the complete valid 2024+ section spine. Its assignment
-- ladder intentionally reproduces the hierarchy formerly embedded in
-- master_section: own enrollment, own valid seats, course enrollment median,
-- course valid-seats median, control/level median, then level median.
--
-- material_costs is one row per canonical Use material at
-- (period_sortable, section_id, isbn13). Catalog duplicates are collapsed before
-- the 1:1 pricing_wide join; catalog-owned copies on pricing_wide are not used.

${CONFIG}

DROP TABLE IF EXISTS _se_base;
DROP TABLE IF EXISTS _se_course_level;
DROP TABLE IF EXISTS _se_signals;
DROP TABLE IF EXISTS _se_enriched;
DROP TABLE IF EXISTS _se_reference;
DROP TABLE IF EXISTS _se_course_agg;
DROP TABLE IF EXISTS _se_class_agg;
DROP TABLE IF EXISTS _se_level_agg;
DROP TABLE IF EXISTS _mc_isbn_metadata;

DROP TABLE IF EXISTS section_enrollment;

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

-- Keep the same native mode() tie behavior used by master_section.
CREATE TEMP TABLE _se_course_level AS
SELECT section_id, mode(course_level) AS course_level
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

-- The reference population and median grouping keys are deliberately identical
-- to the prior master_section implementation.
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

-- Preserve the established Master ISBN metadata contract without making that
-- downstream model read raw catalog rows. These term/ISBN values are repeated on
-- each canonical item so every released material field flows through
-- material_costs.
CREATE TEMP TABLE _mc_isbn_metadata AS
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

DROP TABLE IF EXISTS material_costs;
CREATE TABLE material_costs AS
WITH source AS MATERIALIZED (
    SELECT c.*
    FROM comprehensive_data c
    WHERE c.is_course_material_use
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
      AND c."ISBN13" IS NOT NULL
),
representative AS (
    SELECT * EXCLUDE (representative_rank)
    FROM (
        SELECT
            source.*,
            ROW_NUMBER() OVER (
                PARTITION BY period_sortable, section_id, "ISBN13"
                ORDER BY
                    is_required_inferred DESC,
                    book_status NULLS LAST,
                    "Title" NULLS LAST,
                    "Author" NULLS LAST,
                    "Publisher" NULLS LAST,
                    "FormatType" NULLS LAST,
                    is_oer NULLS LAST,
                    is_ia NULLS LAST,
                    is_supply NULLS LAST,
                    unit_id NULLS LAST,
                    institution_name NULLS LAST,
                    state NULLS LAST,
                    control NULLS LAST,
                    level NULLS LAST,
                    size NULLS LAST,
                    sector NULLS LAST,
                    institution_type NULLS LAST,
                    enrollment_2024 NULLS LAST,
                    distance_enrollment_2024 NULLS LAST,
                    course_id NULLS LAST,
                    course_title NULLS LAST,
                    course_subject NULLS LAST,
                    course_level NULLS LAST,
                    department NULLS LAST,
                    course_number NULLS LAST,
                    section NULLS LAST,
                    period NULLS LAST,
                    enrollments NULLS LAST,
                    seats_taken NULLS LAST,
                    instructor NULLS LAST,
                    first_name NULLS LAST,
                    last_name NULLS LAST,
                    email NULLS LAST,
                    -- Remaining canonical fields break otherwise-equal ties.
                    "Imprint" NULLS LAST,
                    "Format" NULLS LAST,
                    school NULLS LAST,
                    dept_code NULLS LAST,
                    dept_description NULLS LAST,
                    period_date NULLS LAST,
                    oer_category NULLS LAST,
                    ia_category NULLS LAST,
                    supply_category NULLS LAST,
                    panel_response_year NULLS LAST,
                    is_opted_out NULLS LAST,
                    opt_out_source NULLS LAST
            ) AS representative_rank
        FROM source
    ) ranked
    WHERE representative_rank = 1
),
catalog_agg AS (
    SELECT
        period_sortable,
        section_id,
        "ISBN13" AS isbn13,
        BOOL_OR(is_required_inferred) AS is_required_inferred,
        BOOL_OR(is_oer) AS is_oer,
        BOOL_OR(is_ia) AS is_ia,
        BOOL_OR(is_supply) AS is_supply,
        BOOL_OR(book_status = 'required') AS has_book_status_required,
        BOOL_OR(book_status IN ('option', 'recommended'))
            AS has_book_status_optional_recommended,
        COUNT(*) AS source_row_count,
        COUNT(DISTINCT NULLIF(TRIM("Title"), '')) AS title_variant_count,
        COUNT(DISTINCT NULLIF(TRIM("Author"), '')) AS author_variant_count,
        COUNT(DISTINCT NULLIF(TRIM("Publisher"), '')) AS publisher_variant_count,
        COUNT(DISTINCT NULLIF(TRIM("Imprint"), '')) AS imprint_variant_count,
        COUNT(DISTINCT NULLIF(TRIM("Format"), '')) AS book_format_variant_count,
        COUNT(DISTINCT NULLIF(TRIM("FormatType"), '')) AS format_type_variant_count,
        COUNT(DISTINCT NULLIF(TRIM(book_status), '')) AS book_status_variant_count,
        BOOL_OR(is_required_inferred) IS DISTINCT FROM BOOL_AND(is_required_inferred)
            AS is_required_inferred_conflict,
        BOOL_OR(is_oer) IS DISTINCT FROM BOOL_AND(is_oer) AS is_oer_conflict,
        BOOL_OR(is_ia) IS DISTINCT FROM BOOL_AND(is_ia) AS is_ia_conflict
    FROM source
    GROUP BY period_sortable, section_id, "ISBN13"
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
    se.course_level,
    r.course_subject,
    r.period,
    se.enrollments,
    se.seats_taken,
    r.instructor,
    r.first_name,
    r.last_name,
    r.email,
    se.course_id,
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
    se.sector,
    se.level,
    se.control,
    r.size,
    r.enrollment_2024,
    r.distance_enrollment_2024,
    r.institution_type,
    r.panel_response_year,
    r.is_opted_out,
    r.opt_out_source,
    a.is_required_inferred,
    r.is_post_2024,
    r.has_isbn,
    r.has_formattype,
    se.has_enrollment,
    se.has_enrollment_own_seats,
    r.no_details,
    r.no_materials,
    r.is_canada,
    r.is_course_material_use,
    r.is_course_material_no_use,
    se.has_enrollment_sibling,
    se.has_enrollment_sibling_seats,
    se.enrollment_assigned,
    se.enrollment_source,
    a.has_book_status_required,
    a.has_book_status_optional_recommended,
    a.source_row_count,
    a.title_variant_count,
    a.author_variant_count,
    a.publisher_variant_count,
    a.imprint_variant_count,
    a.book_format_variant_count,
    a.format_type_variant_count,
    a.book_status_variant_count,
    (a.title_variant_count > 1
      OR a.author_variant_count > 1
      OR a.publisher_variant_count > 1
      OR a.imprint_variant_count > 1
      OR a.book_format_variant_count > 1
      OR a.format_type_variant_count > 1
      OR a.book_status_variant_count > 1) AS catalog_metadata_conflict,
    a.is_required_inferred_conflict,
    a.is_oer_conflict,
    a.is_ia_conflict,
    pw.bookstore_url,
    pw.price_buy_new_physical,
    pw.price_buy_new_digital,
    pw.price_buy_new_na,
    pw.price_buy_used_physical,
    pw.price_buy_used_digital,
    pw.price_buy_used_na,
    pw.price_buy_na_physical,
    pw.price_buy_na_digital,
    pw.price_buy_na_na,
    pw.price_rental_new_physical,
    pw.price_rental_new_digital,
    pw.price_rental_new_na,
    pw.price_rental_used_physical,
    pw.price_rental_used_digital,
    pw.price_rental_used_na,
    pw.price_rental_na_physical,
    pw.price_rental_na_digital,
    pw.price_rental_na_na,
    pw.format_count,
    pw.has_buy,
    pw.has_rent,
    pw.price_min,
    pw.price_max,
    pw.price_avg,
    pw.rental_days_min,
    pw.rental_days_max,
    pw.price_buy_min,
    pw.price_buy_max,
    (pw.section_id IS NOT NULL) AS has_pricing_match
FROM representative r
JOIN catalog_agg a
  ON r.period_sortable = a.period_sortable
 AND r.section_id = a.section_id
 AND r."ISBN13" = a.isbn13
JOIN section_enrollment se ON r.section_id = se.section_id
JOIN _mc_isbn_metadata im
  ON r.period_sortable = im.period_sortable
 AND r."ISBN13" = im.isbn13
LEFT JOIN pricing_wide pw
  ON r.section_id = pw.section_id
 AND CAST(r."ISBN13" AS VARCHAR) = pw.isbn13;

DROP TABLE _mc_isbn_metadata;

-- Single-line ownership checks for both table grains and required keys.
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

SELECT
    'material_costs grain/key/price DQ' AS metric,
    COUNT(*) AS rows,
    COUNT(*) - COUNT(DISTINCT (period_sortable, section_id, isbn13)) AS duplicate_rows,
    COUNT(*) FILTER (
        WHERE period_sortable IS NULL OR section_id IS NULL OR isbn13 IS NULL
    ) AS key_null_rows,
    COUNT(*) FILTER (WHERE has_pricing_match) AS pricing_match_rows,
    COUNT(*) FILTER (WHERE has_pricing_match AND price_min IS NOT NULL) AS priced_rows,
    COUNT(*) FILTER (WHERE NOT has_pricing_match) AS no_pricing_match_rows
FROM material_costs;

SELECT
    'material_costs duplicate/conflict DQ' AS metric,
    COUNT(*) FILTER (WHERE source_row_count > 1) AS duplicate_source_keys,
    COUNT(*) FILTER (WHERE catalog_metadata_conflict) AS metadata_conflict_keys,
    COUNT(*) FILTER (WHERE is_required_inferred_conflict) AS required_conflict_keys,
    COUNT(*) FILTER (WHERE is_oer_conflict) AS oer_conflict_keys,
    COUNT(*) FILTER (WHERE is_ia_conflict) AS ia_conflict_keys
FROM material_costs;
