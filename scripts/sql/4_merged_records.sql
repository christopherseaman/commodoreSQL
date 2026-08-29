-- Aggregate and transform records by faculty, course sections, and courses

${CONFIG}

-- section_cost: per-(period_sortable, section_id) cost aggregates over canonical
-- Use materials.
-- Required vs non-required uses the catalog classification (is_required_inferred, #1).
-- The canonical issue-#58 Use flag excludes Canada, missing ISBN, supplies, and
-- no-details/no-material placeholders. Cost columns therefore measure only the
-- release material population. material_costs already owns the distinct
-- (period_sortable, section_id, isbn13) grain; NULL-priced materials contribute
-- nothing (*_priced_count shows coverage). "owned" = buy-only (rentals omitted),
-- from material_costs.price_buy_min/max. Materialized as a TABLE so
-- master_section / master_course join it cheaply.
DROP TABLE IF EXISTS section_cost;
CREATE TABLE section_cost AS
WITH materials AS (
    SELECT
        section_id,
        course_id,
        period_sortable,
        isbn13,
        is_required_inferred AS is_required,
        price_min,
        price_max,
        price_buy_min AS owned_min,
        price_buy_max AS owned_max
    FROM material_costs
)
SELECT
    section_id,
    ANY_VALUE(course_id) AS course_id,
    period_sortable,
    SUM(price_min) FILTER (WHERE is_required)     AS required_cost_total_min,
    SUM(price_max) FILTER (WHERE is_required)     AS required_cost_total_max,
    SUM(price_min) FILTER (WHERE NOT is_required) AS optional_cost_total_min,
    SUM(price_max) FILTER (WHERE NOT is_required) AS optional_cost_total_max,
    SUM(owned_min) FILTER (WHERE is_required)     AS required_cost_owned_min,
    SUM(owned_max) FILTER (WHERE is_required)     AS required_cost_owned_max,
    SUM(owned_min) FILTER (WHERE NOT is_required) AS optional_cost_owned_min,
    SUM(owned_max) FILTER (WHERE NOT is_required) AS optional_cost_owned_max,
    COUNT(*) FILTER (WHERE is_required AND price_min IS NOT NULL)     AS required_priced_count,
    COUNT(*) FILTER (WHERE NOT is_required AND price_min IS NOT NULL) AS optional_priced_count
FROM materials
GROUP BY period_sortable, section_id;

-- Create master_section: exactly one row per canonical material-bearing
-- (period_sortable, section_id). material_costs determines the population and all
-- material-facing descriptors/aggregates. Cost columns (#2/#3/#4) join 1:1 on the
-- same explicit key. Enrichment columns live HERE, not in downstream tables:
-- retained-section canonical Course Materials audits (#58/#36) and enrollment fill
-- (#32: enrollment_assigned / enrollment_source from section_enrollment).
-- Materialized as a TABLE (not a VIEW). The build is deliberately staged through
-- narrow TEMP tables: keeping multiple mode() states, publisher lists, and scalar
-- states in one high-cardinality CTAS exceeded host memory. Enrollment medians
-- and the complete valid section population remain owned upstream by
-- section_enrollment; narrowing this release table does not narrow that source.
-- Each stage preserves the original aggregate semantics while allowing prior state
-- to be released before the next high-cardinality aggregate starts.
DROP VIEW  IF EXISTS master_course_material;
DROP VIEW  IF EXISTS master_course;
DROP TABLE IF EXISTS master_section;

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
DROP TABLE IF EXISTS _ms_course_material_audit;
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
    COUNT(*) FILTER (WHERE has_formattype) AS classified_count
FROM material_costs
GROUP BY period_sortable, section_id;

-- Keep native mode() tie behavior, but only one frequency state per pass.
CREATE TEMP TABLE _ms_mode_school AS
SELECT period_sortable, section_id, mode(school) AS school
FROM material_costs
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_department AS
SELECT period_sortable, section_id, mode(department) AS department
FROM material_costs
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_course_number AS
SELECT period_sortable, section_id, mode(course_number) AS course_number
FROM material_costs
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_section AS
SELECT period_sortable, section_id, mode(section) AS section
FROM material_costs
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_course_title AS
SELECT period_sortable, section_id, mode(course_title) AS course_title
FROM material_costs
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_mode_course_subject AS
SELECT period_sortable, section_id, mode(course_subject) AS course_subject
FROM material_costs
GROUP BY period_sortable, section_id;

-- Publisher lists retain the original LIST(DISTINCT) semantics and NULL result
-- for sections with no qualifying publisher. Counts are isolated from list state.
CREATE TEMP TABLE _ms_publishers AS
SELECT period_sortable, section_id, LIST(DISTINCT publisher) AS publishers
FROM material_costs
WHERE publisher IS NOT NULL
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_required_publishers AS
SELECT period_sortable, section_id, LIST(DISTINCT publisher) AS required_publishers
FROM material_costs
WHERE publisher IS NOT NULL
  AND is_required_inferred
GROUP BY period_sortable, section_id;

CREATE TEMP TABLE _ms_publisher_counts AS
SELECT
    period_sortable,
    section_id,
    COUNT(DISTINCT publisher) FILTER (WHERE is_required_inferred) AS required_publisher_count,
    COUNT(DISTINCT publisher) FILTER (WHERE NOT is_required_inferred) AS optional_publisher_count
FROM material_costs
GROUP BY period_sortable, section_id;

-- Canonical Course Materials sidecar: these columns audit excluded/noisy item
-- keys (including the per-section NULL-ISBN audit row) that co-occur with a
-- retained material-bearing section. They do not define Master Section
-- membership or any material-facing aggregate. Raw source-row evidence remains
-- in comprehensive_data and its DQ/mailing/faculty consumers.
CREATE TEMP TABLE _ms_course_material_audit AS
WITH retained_section_keys AS (
    SELECT period_sortable, section_id
    FROM material_costs
    GROUP BY period_sortable, section_id
)
SELECT
    c.period_sortable,
    c.section_id,
    COUNT(*) FILTER (WHERE c.is_course_material_no_use) AS course_material_no_use_count,
    COUNT(*) FILTER (WHERE c.no_details) AS no_details_count,
    COUNT(*) FILTER (WHERE c.no_materials) AS no_materials_count,
    COALESCE(BOOL_OR(c.is_canada), FALSE) AS is_canada,
    COALESCE(BOOL_OR(c.is_supply), FALSE) AS is_supply,
    COUNT(*) FILTER (WHERE c.is_supply) AS supply_count
FROM course_materials c
JOIN retained_section_keys retained
  ON c.period_sortable = retained.period_sortable
 AND c.section_id = retained.section_id
GROUP BY c.period_sortable, c.section_id;

CREATE TEMP TABLE _ms_enriched AS
SELECT
    s.section_id,
    enrollment.course_id,
    s.period,
    s.period_sortable,
    s.period_date,
    s.unit_id,
    s.state,
    enrollment.control,
    enrollment.level,
    s.size,
    enrollment.sector,
    s.institution_name,
    s.institution_type,
    s.enrollment_2024,
    s.distance_enrollment_2024,
    school.school,
    department.department,
    course_number.course_number,
    section_mode.section,
    course_title.course_title,
    enrollment.course_level,
    course_subject.course_subject,
    s.material_count,
    s.required_count,
    s.optional_count,
    s.has_course_material_use,
    s.course_material_use_count,
    audit.course_material_no_use_count,
    audit.no_details_count,
    audit.no_materials_count,
    audit.is_canada,
    audit.is_supply,
    audit.supply_count,
    s.is_oer,
    s.is_ia,
    s.oer_count,
    s.ia_count,
    publishers.publishers,
    required_publishers.required_publishers,
    COALESCE(publisher_counts.required_publisher_count, 0) AS required_publisher_count,
    COALESCE(publisher_counts.optional_publisher_count, 0) AS optional_publisher_count,
    enrollment.enrollments,
    enrollment.seats_taken,
    s.has_isbn,
    s.has_formattype,
    s.isbn_count,
    s.classified_count,
    enrollment.has_enrollment,
    enrollment.has_enrollment_sibling,
    enrollment.has_enrollment_own_seats,
    enrollment.has_enrollment_sibling_seats,
    enrollment.enrollment_assigned,
    enrollment.enrollment_source
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
JOIN _ms_course_material_audit audit
  ON audit.period_sortable = s.period_sortable AND audit.section_id = s.section_id
JOIN section_enrollment enrollment
  ON enrollment.period_sortable = s.period_sortable AND enrollment.section_id = s.section_id;

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
DROP TABLE _ms_course_material_audit;

CREATE TABLE master_section AS
SELECT
    base.*,
    sc.required_cost_total_min, sc.required_cost_total_max,
    sc.optional_cost_total_min, sc.optional_cost_total_max,
    sc.required_cost_owned_min, sc.required_cost_owned_max,
    sc.optional_cost_owned_min, sc.optional_cost_owned_max,
    -- price_avg convention: (min + max) / 2, NOT an arithmetic mean (see CLAUDE.md)
    (sc.required_cost_total_min + sc.required_cost_total_max) / 2.0 AS required_cost_avg,
    (sc.required_cost_owned_min + sc.required_cost_owned_max) / 2.0 AS required_cost_owned_avg,
    (sc.optional_cost_total_min + sc.optional_cost_total_max) / 2.0 AS optional_cost_avg,
    sc.required_priced_count, sc.optional_priced_count
FROM _ms_enriched base
JOIN section_cost sc
  ON sc.period_sortable = base.period_sortable
 AND sc.section_id = base.section_id;

DROP TABLE _ms_enriched;

-- Create master_course: one row per course per period.
-- Cost rolls up section_cost via MIN(min)/MAX(max)/AVG(avg) across the course's
-- sections (sections of a course usually share materials, so SUM would multiply a
-- shared book's cost). Attached at (course_id, period_sortable).
DROP VIEW IF EXISTS master_course;
CREATE VIEW master_course AS
SELECT
    base.*,
    cc.required_cost_total_min, cc.required_cost_total_max,
    cc.optional_cost_total_min, cc.optional_cost_total_max,
    cc.required_cost_owned_min, cc.required_cost_owned_max,
    cc.optional_cost_owned_min, cc.optional_cost_owned_max,
    cc.required_cost_avg, cc.required_cost_owned_avg, cc.optional_cost_avg
FROM (
    SELECT
        course_id,
        period_sortable,
        ANY_VALUE(period)      AS period,
        ANY_VALUE(period_date) AS period_date,
        -- institution enrichment (constant per unit -> per course), carried from master_section
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
        -- OER / IA rollup: indicator = any section is OER/IA; count = sum of section
        -- item counts (consistent with total_materials being a SUM across sections).
        COALESCE(BOOL_OR(is_oer), FALSE) AS is_oer,
        COALESCE(BOOL_OR(is_ia),  FALSE) AS is_ia,
        SUM(oer_count) AS oer_count,
        SUM(ia_count)  AS ia_count,
        -- coverage rollup (2026-06-04 notes): any-section indicator + summed material counts
        COALESCE(BOOL_OR(has_isbn), FALSE)       AS has_isbn,
        COALESCE(BOOL_OR(has_formattype), FALSE) AS has_formattype,
        SUM(isbn_count)       AS isbn_count,
        SUM(classified_count) AS classified_count,
        -- enrollment fill-potential rolled to section counts (of section_count) — how many
        -- of the course's sections carry each signal (2026-06-04 notes).
        COUNT(*) FILTER (WHERE has_enrollment)               AS has_enrollment_sections,
        COUNT(*) FILTER (WHERE has_enrollment_sibling)       AS has_enrollment_sibling_sections,
        COUNT(*) FILTER (WHERE has_enrollment_own_seats)     AS has_enrollment_own_seats_sections,
        COUNT(*) FILTER (WHERE has_enrollment_sibling_seats) AS has_enrollment_sibling_seats_sections,
        LIST(publishers) FILTER (WHERE publishers IS NOT NULL) AS all_publishers,
        SUM(required_publisher_count) AS unique_required_publishers
    FROM master_section
    GROUP BY course_id, period_sortable
) base
LEFT JOIN (
    SELECT
        course_id,
        period_sortable,
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
    FROM section_cost
    GROUP BY course_id, period_sortable
) cc ON base.course_id = cc.course_id AND base.period_sortable = cc.period_sortable;

-- Create master_course_material: material distribution by course at the
-- canonical Material Costs item grain. Source catalog duplicates cannot multiply
-- material_instances or total_seats_affected.
DROP VIEW IF EXISTS master_course_material;
CREATE VIEW master_course_material AS
SELECT
    course_id,
    period,
    period_sortable,
    period_date,
    school,
    department,
    course_number,
    course_title,
    publisher,
    book_status,
    COUNT(*) AS material_instances,
    COUNT(DISTINCT section_id) AS sections_using,
    SUM(seats_taken) AS total_seats_affected
FROM material_costs
WHERE
    course_id IS NOT NULL AND
    publisher IS NOT NULL AND
    period_sortable IS NOT NULL
GROUP BY
    course_id,
    period,
    period_sortable,
    period_date,
    school,
    department,
    course_number,
    course_title,
    publisher,
    book_status;

-- BMG #38: US, intro/intermediate, required-bearing sections (Fall 2025).
-- A pure filtered VIEW of master_section — NO new columns, NO new table. Enrichment
-- lives on master_section itself; downstream artifacts only project/filter it.
-- US only = state excludes 'CAN' (Canada) and blank/unknown-country.
DROP VIEW IF EXISTS master_section_us_intro_fall2025;
CREATE VIEW master_section_us_intro_fall2025 AS
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
SELECT 'master_section keys present in section_enrollment' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE enrollment.section_id IS NULL) AS violations
FROM master_section ms
LEFT JOIN section_enrollment enrollment
  ON enrollment.period_sortable = ms.period_sortable
 AND enrollment.section_id = ms.section_id
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
    FROM material_costs
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
    'material_costs to master_section exact reconciliation' AS metric,
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
    ) AS missing_from_material_costs,
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
      AND period_date >= DATE '2024-01-01'
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
    FROM material_costs
    GROUP BY period_sortable, section_id
    HAVING MIN(course_subject) IS DISTINCT FROM MAX(course_subject)
);

SELECT 'section descriptive divergence (course_number)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM material_costs
    GROUP BY period_sortable, section_id
    HAVING MIN(course_number) IS DISTINCT FROM MAX(course_number)
);

SELECT 'section descriptive divergence (course_title)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM material_costs
    GROUP BY period_sortable, section_id
    HAVING MIN(course_title) IS DISTINCT FROM MAX(course_title)
);

SELECT 'section descriptive divergence (course_level)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM material_costs
    GROUP BY period_sortable, section_id
    HAVING MIN(course_level) IS DISTINCT FROM MAX(course_level)
);

SELECT 'section descriptive divergence (school)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM material_costs
    GROUP BY period_sortable, section_id
    HAVING MIN(school) IS DISTINCT FROM MAX(school)
);

SELECT 'section descriptive divergence (section)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM material_costs
    GROUP BY period_sortable, section_id
    HAVING MIN(section) IS DISTINCT FROM MAX(section)
);

SELECT 'section descriptive divergence (department)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT period_sortable, section_id
    FROM material_costs
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
