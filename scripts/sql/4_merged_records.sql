-- Aggregate and transform records by faculty, course sections, and courses

${CONFIG}

-- Create master_section: exactly one row per canonical material-bearing
-- (period_sortable, section_id). master_material determines the population and all
-- material-facing descriptors/aggregates, including section costs. Enrichment
-- columns live HERE, not in downstream tables:
-- retained-section canonical Course Materials audits (#58/#36) and enrollment fill
-- (#32: enrollment_assigned / enrollment_source inherited from master_material).
-- Materialized as a TABLE (not a VIEW). The build is deliberately staged through
-- narrow TEMP tables: keeping multiple mode() states, publisher lists, and scalar
-- states in one high-cardinality CTAS exceeded host memory. Enrollment medians
-- and the complete valid section population remain owned upstream by
-- section_enrollment; narrowing this release table does not narrow that source.
-- Each stage preserves the original aggregate semantics while allowing prior state
-- to be released before the next high-cardinality aggregate starts.
-- Keep this retirement DROP here as well as in IMPORT cleanup so NO_IMPORT EDA
-- refreshes cannot leave the obsolete view behind.
DROP VIEW  IF EXISTS master_course_material;
DROP VIEW  IF EXISTS master_course;
DROP TABLE IF EXISTS section_cost;
DROP TABLE IF EXISTS master_section;
DROP TABLE IF EXISTS sample10_section_ids;

DROP TABLE IF EXISTS _ms_scalar;
DROP TABLE IF EXISTS _ms_mode_school;
DROP TABLE IF EXISTS _ms_mode_department;
DROP TABLE IF EXISTS _ms_mode_course_number;
DROP TABLE IF EXISTS _ms_mode_section;
DROP TABLE IF EXISTS _ms_mode_course_title;
DROP TABLE IF EXISTS _ms_mode_course_subject;
DROP TABLE IF EXISTS _ms_publishers;
DROP TABLE IF EXISTS _ms_required_publishers;
DROP TABLE IF EXISTS _ms_publisher_counts;
DROP TABLE IF EXISTS _ms_bookstore_url;
DROP TABLE IF EXISTS _ms_enriched;

-- Fixed-size aggregates over canonical Material Costs rows. Descriptive modes and
-- publisher collection states are intentionally isolated below.
CREATE TEMP TABLE _ms_scalar AS
SELECT
    period_sortable,
    section_id,
    ANY_VALUE(period)          AS period,
    ANY_VALUE(period_date)     AS period_date,
    ANY_VALUE(unit_id)                  AS unit_id,
    ANY_VALUE(state)                    AS state,
    ANY_VALUE(size)                     AS size,
    ANY_VALUE(institution_name)         AS institution_name,
    ANY_VALUE(institution_type)         AS institution_type,
    ANY_VALUE(enrollment_2024)          AS enrollment_2024,
    ANY_VALUE(distance_enrollment_2024) AS distance_enrollment_2024,
    ANY_VALUE(course_id) AS course_id,
    ANY_VALUE(control) AS control,
    ANY_VALUE(level) AS level,
    ANY_VALUE(sector) AS sector,
    ANY_VALUE(course_level) AS course_level,
    ANY_VALUE(enrollments) AS enrollments,
    ANY_VALUE(seats_taken) AS seats_taken,
    ANY_VALUE(has_enrollment) AS has_enrollment,
    ANY_VALUE(has_enrollment_sibling) AS has_enrollment_sibling,
    ANY_VALUE(has_enrollment_own_seats) AS has_enrollment_own_seats,
    ANY_VALUE(has_enrollment_sibling_seats) AS has_enrollment_sibling_seats,
    ANY_VALUE(enrollment_assigned) AS enrollment_assigned,
    ANY_VALUE(enrollment_source) AS enrollment_source,
    COALESCE(BOOL_OR(is_section_required_direct), FALSE) AS is_required_direct,
    COUNT(*) AS material_count,
    COUNT(*) FILTER (WHERE is_required_inferred)     AS required_count,
    COUNT(*) FILTER (WHERE NOT is_required_inferred) AS optional_count,
    TRUE AS has_course_material_use,
    COUNT(*) AS course_material_use_count,
    COALESCE(BOOL_OR(is_oer), FALSE) AS is_oer,
    COALESCE(BOOL_OR(is_ia),  FALSE) AS is_ia,
    COUNT(*) FILTER (WHERE is_oer) AS oer_count,
    COUNT(*) FILTER (WHERE is_ia)  AS ia_count,
    COALESCE(BOOL_OR(has_isbn), FALSE) AS has_isbn,
    COALESCE(BOOL_OR(has_formattype), FALSE) AS has_formattype,
    COUNT(*) FILTER (WHERE has_isbn)       AS isbn_count,
    COUNT(*) FILTER (WHERE has_formattype) AS classified_count,
    SUM(price_min) FILTER (WHERE is_required_inferred) AS required_cost_total_min,
    SUM(price_max) FILTER (WHERE is_required_inferred) AS required_cost_total_max,
    SUM(price_min) FILTER (WHERE NOT is_required_inferred) AS optional_cost_total_min,
    SUM(price_max) FILTER (WHERE NOT is_required_inferred) AS optional_cost_total_max,
    SUM(price_buy_min) FILTER (WHERE is_required_inferred) AS required_cost_owned_min,
    SUM(price_buy_max) FILTER (WHERE is_required_inferred) AS required_cost_owned_max,
    SUM(price_buy_min) FILTER (WHERE NOT is_required_inferred) AS optional_cost_owned_min,
    SUM(price_buy_max) FILTER (WHERE NOT is_required_inferred) AS optional_cost_owned_max,
    COUNT(*) FILTER (WHERE is_required_inferred AND price_min IS NOT NULL) AS required_priced_count,
    COUNT(*) FILTER (WHERE NOT is_required_inferred AND price_min IS NOT NULL) AS optional_priced_count,
    ANY_VALUE(section_course_material_no_use_count) AS course_material_no_use_count,
    ANY_VALUE(section_no_details_count) AS no_details_count,
    ANY_VALUE(section_no_materials_count) AS no_materials_count,
    ANY_VALUE(is_section_canada) AS is_canada,
    ANY_VALUE(is_section_supply) AS is_supply,
    ANY_VALUE(section_supply_count) AS supply_count
FROM master_material
GROUP BY period_sortable, section_id;

-- Keep native mode() tie behavior, but only one frequency state per pass.
CREATE TEMP TABLE _ms_mode_school AS
SELECT period_sortable, section_id, mode(school) AS school
FROM master_material
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_department AS
SELECT period_sortable, section_id, mode(department) AS department
FROM master_material
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_course_number AS
SELECT period_sortable, section_id, mode(course_number) AS course_number
FROM master_material
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_section AS
SELECT period_sortable, section_id, mode(section) AS section
FROM master_material
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_course_title AS
SELECT period_sortable, section_id, mode(course_title) AS course_title
FROM master_material
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_course_subject AS
SELECT period_sortable, section_id, mode(course_subject) AS course_subject
FROM master_material
GROUP BY period_sortable, section_id;

-- Publisher lists retain the original LIST(DISTINCT) semantics and NULL result
-- for sections with no qualifying publisher. Counts are isolated from list state.
CREATE TEMP TABLE _ms_publishers AS
SELECT period_sortable, section_id, LIST(DISTINCT publisher) AS publishers
FROM master_material
WHERE publisher IS NOT NULL
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_required_publishers AS
SELECT period_sortable, section_id, LIST(DISTINCT publisher) AS required_publishers
FROM master_material
WHERE publisher IS NOT NULL
  AND is_required_inferred
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_publisher_counts AS
SELECT
    period_sortable,
    section_id,
    COUNT(DISTINCT publisher) FILTER (WHERE is_required_inferred) AS required_publisher_count,
    COUNT(DISTINCT publisher) FILTER (WHERE NOT is_required_inferred) AS optional_publisher_count
FROM master_material
GROUP BY period_sortable, section_id;

-- Section-level bookstore URL is the most frequent nonblank exact-price URL
-- among canonical Use items; lexical ordering resolves ties deterministically.
CREATE TEMP TABLE _ms_bookstore_url AS
WITH url_counts AS (
    SELECT
        period_sortable,
        section_id,
        NULLIF(TRIM(bookstore_url), '') AS bookstore_url,
        COUNT(*) AS material_count
    FROM master_material
    WHERE NULLIF(TRIM(bookstore_url), '') IS NOT NULL
    GROUP BY 1, 2, 3
), ranked_urls AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY period_sortable, section_id
            ORDER BY material_count DESC, bookstore_url ASC
        ) AS url_rank
    FROM url_counts
)
SELECT period_sortable, section_id, bookstore_url
FROM ranked_urls
WHERE url_rank = 1;

CREATE TEMP TABLE _ms_enriched AS
SELECT
    s.section_id,
    s.course_id,
    s.period,
    s.period_sortable,
    s.period_date,
    s.unit_id,
    s.state,
    s.control,
    s.level,
    s.size,
    s.sector,
    s.institution_name,
    s.institution_type,
    s.enrollment_2024,
    s.distance_enrollment_2024,
    school.school,
    department.department,
    course_number.course_number,
    section_mode.section,
    course_title.course_title,
    s.course_level,
    course_subject.course_subject,
    s.material_count,
    s.required_count,
    s.optional_count,
    s.has_course_material_use,
    s.course_material_use_count,
    s.course_material_no_use_count,
    s.no_details_count,
    s.no_materials_count,
    s.is_canada,
    s.is_supply,
    s.supply_count,
    s.is_oer,
    s.is_ia,
    s.oer_count,
    s.ia_count,
    publishers.publishers,
    required_publishers.required_publishers,
    COALESCE(publisher_counts.required_publisher_count, 0) AS required_publisher_count,
    COALESCE(publisher_counts.optional_publisher_count, 0) AS optional_publisher_count,
    s.enrollments,
    s.seats_taken,
    s.has_isbn,
    s.has_formattype,
    s.isbn_count,
    s.classified_count,
    s.has_enrollment,
    s.has_enrollment_sibling,
    s.has_enrollment_own_seats,
    s.has_enrollment_sibling_seats,
    s.enrollment_assigned,
    s.enrollment_source,
    s.is_required_direct,
    s.required_cost_total_min,
    s.required_cost_total_max,
    s.optional_cost_total_min,
    s.optional_cost_total_max,
    s.required_cost_owned_min,
    s.required_cost_owned_max,
    s.optional_cost_owned_min,
    s.optional_cost_owned_max,
    s.required_priced_count,
    s.optional_priced_count,
    url.bookstore_url
FROM _ms_scalar s
JOIN _ms_mode_school school
  ON school.period_sortable = s.period_sortable AND school.section_id = s.section_id
JOIN _ms_mode_department department
  ON department.period_sortable = s.period_sortable AND department.section_id = s.section_id
JOIN _ms_mode_course_number course_number
  ON course_number.period_sortable = s.period_sortable AND course_number.section_id = s.section_id
JOIN _ms_mode_section section_mode
  ON section_mode.period_sortable = s.period_sortable AND section_mode.section_id = s.section_id
JOIN _ms_mode_course_title course_title
  ON course_title.period_sortable = s.period_sortable AND course_title.section_id = s.section_id
JOIN _ms_mode_course_subject course_subject
  ON course_subject.period_sortable = s.period_sortable AND course_subject.section_id = s.section_id
LEFT JOIN _ms_publishers publishers
  ON publishers.period_sortable = s.period_sortable AND publishers.section_id = s.section_id
LEFT JOIN _ms_required_publishers required_publishers
  ON required_publishers.period_sortable = s.period_sortable
 AND required_publishers.section_id = s.section_id
LEFT JOIN _ms_publisher_counts publisher_counts
  ON publisher_counts.period_sortable = s.period_sortable
 AND publisher_counts.section_id = s.section_id
LEFT JOIN _ms_bookstore_url url
  ON url.period_sortable = s.period_sortable AND url.section_id = s.section_id;

DROP TABLE _ms_scalar;
DROP TABLE _ms_mode_school;
DROP TABLE _ms_mode_department;
DROP TABLE _ms_mode_course_number;
DROP TABLE _ms_mode_section;
DROP TABLE _ms_mode_course_title;
DROP TABLE _ms_mode_course_subject;
DROP TABLE _ms_publishers;
DROP TABLE _ms_required_publishers;
DROP TABLE _ms_publisher_counts;
DROP TABLE _ms_bookstore_url;

CREATE TABLE master_section AS
SELECT
    base.* EXCLUDE (required_priced_count, optional_priced_count, bookstore_url),
    -- price_avg convention: (min + max) / 2, NOT an arithmetic mean (see CLAUDE.md)
    (base.required_cost_total_min + base.required_cost_total_max) / 2.0 AS required_cost_avg,
    (base.required_cost_owned_min + base.required_cost_owned_max) / 2.0 AS required_cost_owned_avg,
    (base.optional_cost_total_min + base.optional_cost_total_max) / 2.0 AS optional_cost_avg,
    base.required_priced_count,
    base.optional_priced_count,
    base.bookstore_url
FROM _ms_enriched base;

DROP TABLE _ms_enriched;

-- Create master_course: one row per course per period.
-- Cost rolls up master_section via MIN(min)/MAX(max)/AVG(avg) across the course's
-- sections (sections of a course usually share materials, so SUM would multiply a
-- shared book's cost). Attached at (course_id, period_sortable).
DROP VIEW IF EXISTS master_course;
CREATE VIEW master_course AS
SELECT
    course_id,
    period_sortable,
    ANY_VALUE(period)      AS period,
    ANY_VALUE(period_date) AS period_date,
    ANY_VALUE(unit_id)                  AS unit_id,
    ANY_VALUE(state)                    AS state,
    ANY_VALUE(control)                  AS control,
    ANY_VALUE(level)                    AS level,
    ANY_VALUE(size)                     AS size,
    ANY_VALUE(sector)                   AS sector,
    ANY_VALUE(institution_name)         AS institution_name,
    ANY_VALUE(institution_type)         AS institution_type,
    ANY_VALUE(enrollment_2024)          AS enrollment_2024,
    ANY_VALUE(distance_enrollment_2024) AS distance_enrollment_2024,
    mode(school)           AS school,
    mode(department)       AS department,
    mode(course_number)    AS course_number,
    mode(course_title)     AS course_title,
    mode(course_level)     AS course_level,
    mode(course_subject)   AS course_subject,
    COUNT(DISTINCT section_id) AS section_count,
    SUM(enrollments) AS enrollment_total,
    SUM(seats_taken) AS seats_taken_total,
    SUM(material_count) AS total_materials,
    SUM(required_count) AS total_required,
    SUM(optional_count) AS total_optional,
    COALESCE(BOOL_OR(is_oer), FALSE) AS is_oer,
    COALESCE(BOOL_OR(is_ia),  FALSE) AS is_ia,
    SUM(oer_count) AS oer_count,
    SUM(ia_count)  AS ia_count,
    COALESCE(BOOL_OR(has_isbn), FALSE)       AS has_isbn,
    COALESCE(BOOL_OR(has_formattype), FALSE) AS has_formattype,
    SUM(isbn_count)       AS isbn_count,
    SUM(classified_count) AS classified_count,
    COUNT(*) FILTER (WHERE has_enrollment)               AS has_enrollment_sections,
    COUNT(*) FILTER (WHERE has_enrollment_sibling)       AS has_enrollment_sibling_sections,
    COUNT(*) FILTER (WHERE has_enrollment_own_seats)     AS has_enrollment_own_seats_sections,
    COUNT(*) FILTER (WHERE has_enrollment_sibling_seats) AS has_enrollment_sibling_seats_sections,
    LIST(publishers) FILTER (WHERE publishers IS NOT NULL) AS all_publishers,
    SUM(required_publisher_count) AS unique_required_publishers,
    MIN(required_cost_total_min) AS required_cost_total_min,
    MAX(required_cost_total_max) AS required_cost_total_max,
    MIN(optional_cost_total_min) AS optional_cost_total_min,
    MAX(optional_cost_total_max) AS optional_cost_total_max,
    MIN(required_cost_owned_min) AS required_cost_owned_min,
    MAX(required_cost_owned_max) AS required_cost_owned_max,
    MIN(optional_cost_owned_min) AS optional_cost_owned_min,
    MAX(optional_cost_owned_max) AS optional_cost_owned_max,
    AVG((required_cost_total_min + required_cost_total_max) / 2.0) AS required_cost_avg,
    AVG((required_cost_owned_min + required_cost_owned_max) / 2.0) AS required_cost_owned_avg,
    AVG((optional_cost_total_min + optional_cost_total_max) / 2.0) AS optional_cost_avg
FROM master_section
GROUP BY course_id, period_sortable;

-- BMG #38: US, intro/intermediate, required-bearing sections (Fall 2025).
-- A pure filtered VIEW of master_section — NO new columns, NO new table. Enrichment
-- lives on master_section itself; downstream artifacts only project/filter it.
-- US only = state excludes 'CAN' (Canada) and blank/unknown-country.
DROP VIEW IF EXISTS master_section_us_intro_fall2025;
DROP VIEW IF EXISTS sample_section_us_intro_fall2025;
CREATE VIEW sample_section_us_intro_fall2025 AS
SELECT *
FROM master_section
WHERE period_sortable = '2025-4'
  AND required_count >= 1
  AND course_level IN ('Introductory or general undergraduate', 'Intermediate undergraduate')
  AND state NOT IN ('CAN', '');

-- DQ: canonical material counts and the retained-section sidecar invariants.
SELECT 'master_section reconciliation' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (
           WHERE required_count + optional_count <> material_count
              OR material_count <> course_material_use_count
              OR material_count <= 0
              OR has_course_material_use <> (course_material_use_count > 0)
       ) AS violations
FROM master_section
UNION ALL
SELECT 'master_course reconciliation' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE total_required + total_optional <> total_materials) AS violations
FROM master_course
UNION ALL
SELECT 'master_section OER/IA invariant' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE is_oer <> (oer_count > 0) OR is_ia <> (ia_count > 0)) AS violations
FROM master_section
UNION ALL
SELECT 'master_section cost min<=max' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE required_cost_total_min > required_cost_total_max
                           OR optional_cost_total_min > optional_cost_total_max
                           OR required_cost_owned_min > required_cost_owned_max
                           OR optional_cost_owned_min > optional_cost_owned_max) AS violations
FROM master_section
UNION ALL
SELECT 'master_section supply invariant (#36)' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE is_supply <> (supply_count > 0)) AS violations
FROM master_section
UNION ALL
SELECT 'master_section enrollment_assigned invariant (#32)' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE ((enrollment_source = 'own') <> has_enrollment)
                           OR ((enrollment_assigned IS NULL) <> (enrollment_source = 'none'))) AS violations
FROM master_section
UNION ALL
SELECT 'master_section unique per (period_sortable, section_id)' AS metric,
       COUNT(*) AS rows,
       COUNT(*) - COUNT(DISTINCT (period_sortable, section_id)) AS violations
FROM master_section
UNION ALL
SELECT 'master_section period-key consistency' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (
           WHERE REGEXP_EXTRACT(section_id, '::([0-9]{4}-[1-4])$', 1)
                 IS DISTINCT FROM period_sortable
       ) AS violations
FROM master_section
UNION ALL
SELECT 'master_course unique per (course_id, period_sortable)' AS metric,
       COUNT(*) AS rows,
       COUNT(*) - COUNT(DISTINCT (course_id, period_sortable)) AS violations
FROM master_course;

-- DQ: Material Costs is the exact Master Section population and item source.
-- Missing/extra keys and item-count mismatches must all be zero.
WITH material_section_counts AS MATERIALIZED (
    SELECT
        period_sortable,
        section_id,
        COUNT(*) AS item_count
    FROM master_material
    GROUP BY period_sortable, section_id
),
key_presence AS (
    SELECT
        COALESCE(material.period_sortable, master.period_sortable) AS period_sortable,
        material.section_id AS material_section_id,
        material.item_count,
        master.section_id AS master_section_id,
        master.material_count
    FROM material_section_counts material
    FULL OUTER JOIN master_section master
      ON master.period_sortable = material.period_sortable
     AND master.section_id = material.section_id
)
SELECT
    'master_material to master_section exact reconciliation' AS metric,
    period_sortable,
    COUNT(material_section_id) AS material_section_rows,
    COUNT(master_section_id) AS master_section_rows,
    SUM(COALESCE(item_count, 0)) AS material_item_rows,
    SUM(COALESCE(material_count, 0)) AS master_material_count,
    COUNT(*) FILTER (
        WHERE material_section_id IS NOT NULL AND master_section_id IS NULL
    ) AS missing_from_master_section,
    COUNT(*) FILTER (
        WHERE material_section_id IS NULL AND master_section_id IS NOT NULL
    ) AS missing_from_master_material,
    COUNT(*) FILTER (
        WHERE item_count IS DISTINCT FROM material_count
    ) AS material_count_violations
FROM key_presence
GROUP BY period_sortable
ORDER BY period_sortable;

-- Full-population diagnostics remain on comprehensive_data and
-- section_enrollment. They deliberately do not claim that narrowed Master Section
-- conserves the raw Use/NoUse partition or the complete section spine.
WITH catalog_by_term AS (
    SELECT
        period_sortable,
        COUNT(*) AS catalog_rows,
        COUNT(DISTINCT section_id) AS catalog_sections,
        COUNT(*) FILTER (WHERE is_course_material_use) AS use_rows,
        COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_rows
    FROM comprehensive_data
    WHERE section_id IS NOT NULL
      AND period_sortable IS NOT NULL
      AND period_sortable IN (SELECT period_sortable FROM recent_period)
    GROUP BY period_sortable
),
enrollment_by_term AS (
    SELECT
        period_sortable,
        COUNT(*) AS enrollment_sections,
        COUNT(DISTINCT section_id) AS unique_enrollment_sections
    FROM section_enrollment
    GROUP BY period_sortable
)
SELECT
    'full catalog/section_enrollment population diagnostics' AS metric,
    COALESCE(catalog.period_sortable, enrollment.period_sortable) AS period_sortable,
    COALESCE(catalog.catalog_rows, 0) AS catalog_rows,
    COALESCE(catalog.catalog_sections, 0) AS catalog_sections,
    COALESCE(enrollment.enrollment_sections, 0) AS enrollment_sections,
    COALESCE(catalog.catalog_rows, 0)
      - COALESCE(catalog.use_rows, 0)
      - COALESCE(catalog.no_use_rows, 0) AS catalog_partition_violations,
    COALESCE(enrollment.enrollment_sections, 0)
      - COALESCE(enrollment.unique_enrollment_sections, 0) AS enrollment_uniqueness_violations,
    ABS(COALESCE(catalog.catalog_sections, 0)
      - COALESCE(enrollment.enrollment_sections, 0)) AS section_population_count_difference
FROM catalog_by_term catalog
FULL OUTER JOIN enrollment_by_term enrollment USING (period_sortable)
ORDER BY period_sortable;

-- Informational excluded canonical-item sidecar mix among retained
-- material-bearing sections.
SELECT
    'master_section course-material sidecar mix' AS metric,
    period_sortable,
    COUNT(*) FILTER (WHERE course_material_no_use_count = 0) AS canonical_only_sections,
    COUNT(*) FILTER (WHERE course_material_no_use_count > 0) AS sections_with_no_use_rows,
    SUM(course_material_no_use_count) AS audited_no_use_items,
    SUM(no_details_count) AS audited_no_details_items,
    SUM(no_materials_count) AS audited_no_materials_items,
    SUM(supply_count) AS audited_supply_items,
    COUNT(*) FILTER (WHERE is_canada) AS sections_with_canada_rows
FROM master_section
GROUP BY period_sortable
ORDER BY period_sortable;

-- DQ (informational, #24): mode() flattens canonical-item metadata divergence.
-- Run one fixed-state aggregate per field to keep memory bounded.
SELECT 'section descriptive divergence (course_subject)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM master_material
    GROUP BY period_sortable, section_id
    HAVING MIN(course_subject) IS DISTINCT FROM MAX(course_subject)
);

SELECT 'section descriptive divergence (course_number)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM master_material
    GROUP BY period_sortable, section_id
    HAVING MIN(course_number) IS DISTINCT FROM MAX(course_number)
);

SELECT 'section descriptive divergence (course_title)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM master_material
    GROUP BY period_sortable, section_id
    HAVING MIN(course_title) IS DISTINCT FROM MAX(course_title)
);

SELECT 'section descriptive divergence (course_level)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM master_material
    GROUP BY period_sortable, section_id
    HAVING MIN(course_level) IS DISTINCT FROM MAX(course_level)
);

SELECT 'section descriptive divergence (school)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM master_material
    GROUP BY period_sortable, section_id
    HAVING MIN(school) IS DISTINCT FROM MAX(school)
);

SELECT 'section descriptive divergence (section)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM master_material
    GROUP BY period_sortable, section_id
    HAVING MIN(section) IS DISTINCT FROM MAX(section)
);

SELECT 'section descriptive divergence (department)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM master_material
    GROUP BY period_sortable, section_id
    HAVING MIN(department) IS DISTINCT FROM MAX(department)
);

-- Coverage summary (informational, 2026-06-04 notes). Values are NOT imputed; these
-- quantify how much of the missing-enrollment gap COULD be filled from each signal, and
-- how many materials are ISBN'd / OER-IA-classifiable. The fillable signals overlap (a
-- section can be fillable from more than one), so they do not sum to (missing - unfillable).
SELECT 'enrollment fill-potential (sections)' AS note,
       COUNT(*) FILTER (WHERE has_enrollment)                                          AS has_enrollment,
       COUNT(*) FILTER (WHERE NOT has_enrollment)                                      AS missing,
       COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_sibling)           AS missing_w_sibling_enroll,
       COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_own_seats)         AS missing_w_own_seats,
       COUNT(*) FILTER (WHERE NOT has_enrollment AND has_enrollment_sibling_seats)     AS missing_w_sibling_seats,
       COUNT(*) FILTER (WHERE NOT has_enrollment AND NOT has_enrollment_sibling
                          AND NOT has_enrollment_own_seats
                          AND NOT has_enrollment_sibling_seats)                        AS unfillable
FROM master_section;

SELECT 'OER/IA + ISBN coverage' AS note,
       COUNT(*) FILTER (WHERE has_isbn)       AS sections_with_isbn,
       COUNT(*) FILTER (WHERE has_formattype) AS sections_with_classified,
       SUM(isbn_count)       AS isbn_materials,
       SUM(classified_count) AS classified_materials
FROM master_section;

-- Supply exclusion summary (informational, #36): supply is the canonical
-- Course Materials sidecar for excluded items co-occurring with retained
-- material-bearing sections.
SELECT 'supply exclusion (sections)' AS note,
       COUNT(*) FILTER (WHERE is_supply) AS sections_with_supply,
       SUM(supply_count)                 AS supply_materials,
       COUNT(*) FILTER (WHERE is_supply AND material_count > 0) AS supply_with_material_sections
FROM master_section;

-- Enrollment assignment source mix (informational, #32): sections per fill rung.
SELECT 'enrollment_assigned source mix (sections)' AS note,
       COUNT(*) FILTER (WHERE enrollment_source = 'own')            AS own,
       COUNT(*) FILTER (WHERE enrollment_source = 'own_seats')      AS own_seats,
       COUNT(*) FILTER (WHERE enrollment_source = 'sibling_enroll') AS sibling_enroll,
       COUNT(*) FILTER (WHERE enrollment_source = 'sibling_seats')  AS sibling_seats,
       COUNT(*) FILTER (WHERE enrollment_source = 'class_median')   AS class_median,
       COUNT(*) FILTER (WHERE enrollment_source = 'level_median')   AS level_median,
       COUNT(*) FILTER (WHERE enrollment_source = 'none')           AS unassigned
FROM master_section;
