-- Aggregate and transform records by faculty, course sections, and courses

${CONFIG}

-- section_cost: per-section cost aggregates over canonical Use materials.
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
    MAX(course_id)       AS course_id,
    MAX(period_sortable) AS period_sortable,
    SUM(price_min) FILTER (WHERE is_required)     AS required_cost_total_min,
    SUM(price_max) FILTER (WHERE is_required)     AS required_cost_total_max,
    SUM(price_min) FILTER (WHERE NOT is_required) AS optional_cost_total_min,
    SUM(price_max) FILTER (WHERE NOT is_required) AS optional_cost_total_max,
    SUM(owned_min) FILTER (WHERE is_required)     AS required_cost_owned_min,
    SUM(owned_max) FILTER (WHERE is_required)     AS required_cost_owned_max,
    SUM(owned_min) FILTER (WHERE NOT is_required) AS optional_cost_owned_min,
    SUM(owned_max) FILTER (WHERE NOT is_required) AS optional_cost_owned_max,
    COUNT(DISTINCT isbn13) FILTER (WHERE is_required AND price_min IS NOT NULL)     AS required_priced_count,
    COUNT(DISTINCT isbn13) FILTER (WHERE NOT is_required AND price_min IS NOT NULL) AS optional_priced_count
FROM materials
GROUP BY section_id;

-- Create master_section: exactly one row per section_id (2024+). Collapsed by section_id;
-- descriptive cols resolved via mode() (most-frequent) / ANY_VALUE (constant) / MAX (#24 —
-- see the divergence DQ at the bottom). Cost columns (#2/#3/#4) join 1:1 on section_id.
-- Enrichment columns live HERE, not in downstream tables: population audit (#58),
-- supply audit (#36, across all rows), and enrollment fill
-- (#32: enrollment_assigned / enrollment_source from section_enrollment).
-- Materialized as a TABLE (not a VIEW). The build is deliberately staged through
-- narrow TEMP tables: keeping seven mode() states, publisher lists, and scalar
-- states in one 23.6M-group CTAS exceeded host memory. Enrollment medians are
-- now owned upstream by section_enrollment.
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
DROP TABLE IF EXISTS _ms_enriched;

-- Fixed-size aggregates over the full section spine. Descriptive modes and
-- publisher collection states are intentionally isolated below.
CREATE TEMP TABLE _ms_scalar AS
SELECT
    section_id,
    ANY_VALUE(period)          AS period,
    ANY_VALUE(period_sortable) AS period_sortable,
    ANY_VALUE(period_date)     AS period_date,
    ANY_VALUE(unit_id)                  AS unit_id,
    ANY_VALUE(state)                    AS state,
    ANY_VALUE(size)                     AS size,
    ANY_VALUE(institution_name)         AS institution_name,
    ANY_VALUE(institution_type)         AS institution_type,
    ANY_VALUE(enrollment_2024)          AS enrollment_2024,
    ANY_VALUE(distance_enrollment_2024) AS distance_enrollment_2024,
    COUNT(*) FILTER (WHERE is_course_material_use) AS material_count,
    COUNT(*) FILTER (WHERE is_required_inferred AND is_course_material_use)     AS required_count,
    COUNT(*) FILTER (WHERE NOT is_required_inferred AND is_course_material_use) AS optional_count,
    COALESCE(BOOL_OR(is_course_material_use), FALSE) AS has_course_material_use,
    COUNT(*) FILTER (WHERE is_course_material_use)    AS course_material_use_count,
    COUNT(*) FILTER (WHERE is_course_material_no_use) AS course_material_no_use_count,
    COUNT(*) FILTER (WHERE no_details)                 AS no_details_count,
    COUNT(*) FILTER (WHERE no_materials)               AS no_materials_count,
    COALESCE(BOOL_OR(is_canada), FALSE) AS is_canada,
    COALESCE(BOOL_OR(is_supply), FALSE) AS is_supply,
    COUNT(*) FILTER (WHERE is_supply)   AS supply_count,
    COALESCE(BOOL_OR(is_oer) FILTER (WHERE is_course_material_use), FALSE) AS is_oer,
    COALESCE(BOOL_OR(is_ia)  FILTER (WHERE is_course_material_use), FALSE) AS is_ia,
    COUNT(*) FILTER (WHERE is_oer AND is_course_material_use) AS oer_count,
    COUNT(*) FILTER (WHERE is_ia AND is_course_material_use)  AS ia_count,
    COALESCE(BOOL_OR(has_isbn) FILTER (WHERE is_course_material_use), FALSE) AS has_isbn,
    COALESCE(BOOL_OR(has_formattype) FILTER (WHERE is_course_material_use), FALSE) AS has_formattype,
    COUNT(*) FILTER (WHERE has_isbn AND is_course_material_use)       AS isbn_count,
    COUNT(*) FILTER (WHERE has_formattype AND is_course_material_use) AS classified_count
FROM comprehensive_data
WHERE section_id IS NOT NULL
  AND period_sortable IS NOT NULL
  AND period_date >= '2024-01-01'
GROUP BY section_id;

-- Keep native mode() tie behavior, but only one frequency state per pass.
CREATE TEMP TABLE _ms_mode_school AS
SELECT section_id, mode(school) AS school
FROM comprehensive_data
WHERE section_id IS NOT NULL AND period_sortable IS NOT NULL AND period_date >= '2024-01-01'
GROUP BY section_id;

CREATE TEMP TABLE _ms_mode_department AS
SELECT section_id, mode(department) AS department
FROM comprehensive_data
WHERE section_id IS NOT NULL AND period_sortable IS NOT NULL AND period_date >= '2024-01-01'
GROUP BY section_id;

CREATE TEMP TABLE _ms_mode_course_number AS
SELECT section_id, mode(course_number) AS course_number
FROM comprehensive_data
WHERE section_id IS NOT NULL AND period_sortable IS NOT NULL AND period_date >= '2024-01-01'
GROUP BY section_id;

CREATE TEMP TABLE _ms_mode_section AS
SELECT section_id, mode(section) AS section
FROM comprehensive_data
WHERE section_id IS NOT NULL AND period_sortable IS NOT NULL AND period_date >= '2024-01-01'
GROUP BY section_id;

CREATE TEMP TABLE _ms_mode_course_title AS
SELECT section_id, mode(course_title) AS course_title
FROM comprehensive_data
WHERE section_id IS NOT NULL AND period_sortable IS NOT NULL AND period_date >= '2024-01-01'
GROUP BY section_id;

CREATE TEMP TABLE _ms_mode_course_subject AS
SELECT section_id, mode(course_subject) AS course_subject
FROM comprehensive_data
WHERE section_id IS NOT NULL AND period_sortable IS NOT NULL AND period_date >= '2024-01-01'
GROUP BY section_id;

-- Publisher lists retain the original LIST(DISTINCT) semantics and NULL result
-- for sections with no qualifying publisher. Counts are isolated from list state.
CREATE TEMP TABLE _ms_publishers AS
SELECT section_id, LIST(DISTINCT publisher) AS publishers
FROM comprehensive_data
WHERE section_id IS NOT NULL
  AND period_sortable IS NOT NULL
  AND period_date >= '2024-01-01'
  AND publisher IS NOT NULL
  AND is_course_material_use
GROUP BY section_id;

CREATE TEMP TABLE _ms_required_publishers AS
SELECT section_id, LIST(DISTINCT publisher) AS required_publishers
FROM comprehensive_data
WHERE section_id IS NOT NULL
  AND period_sortable IS NOT NULL
  AND period_date >= '2024-01-01'
  AND publisher IS NOT NULL
  AND is_required_inferred
  AND is_course_material_use
GROUP BY section_id;

CREATE TEMP TABLE _ms_publisher_counts AS
SELECT
    section_id,
    COUNT(DISTINCT publisher) FILTER (WHERE is_required_inferred) AS required_publisher_count,
    COUNT(DISTINCT publisher) FILTER (WHERE NOT is_required_inferred) AS optional_publisher_count
FROM comprehensive_data
WHERE section_id IS NOT NULL
  AND period_sortable IS NOT NULL
  AND period_date >= '2024-01-01'
  AND is_course_material_use
GROUP BY section_id;

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
JOIN _ms_mode_school school USING (section_id)
JOIN _ms_mode_department department USING (section_id)
JOIN _ms_mode_course_number course_number USING (section_id)
JOIN _ms_mode_section section_mode USING (section_id)
JOIN _ms_mode_course_title course_title USING (section_id)
JOIN _ms_mode_course_subject course_subject USING (section_id)
LEFT JOIN _ms_publishers publishers USING (section_id)
LEFT JOIN _ms_required_publishers required_publishers USING (section_id)
LEFT JOIN _ms_publisher_counts publisher_counts USING (section_id)
JOIN section_enrollment enrollment USING (section_id);

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
LEFT JOIN section_cost sc ON base.section_id = sc.section_id;

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

-- Create master_course_material: material distribution by course
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
FROM comprehensive_data
WHERE
    course_id IS NOT NULL AND
    publisher IS NOT NULL AND
    period_sortable IS NOT NULL AND
    -- 2024+ scope, consistent with master_section / master_course (#24)
    period_date >= '2024-01-01' AND
    -- #58: canonical Use population, consistent with every material aggregate.
    is_course_material_use
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

-- DQ: the canonical Use count is material_count, and inferred required/optional
-- partition it. The full section spine and the all-row supply/enrollment audits
-- remain independent of material eligibility.
SELECT 'master_section reconciliation' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (
           WHERE required_count + optional_count <> material_count
              OR material_count <> course_material_use_count
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
SELECT 'master_section Canada subset NoUse (#58)' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (
           WHERE is_canada
             AND (course_material_use_count > 0 OR course_material_no_use_count = 0)
       ) AS violations
FROM master_section
UNION ALL
SELECT 'master_section enrollment_assigned invariant (#32)' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE ((enrollment_source = 'own') <> has_enrollment)
                           OR ((enrollment_assigned IS NULL) <> (enrollment_source = 'none'))) AS violations
FROM master_section
UNION ALL
SELECT 'master_section unique per section_id' AS metric,
       COUNT(*) AS rows,
       COUNT(*) - COUNT(DISTINCT section_id) AS violations
FROM master_section
UNION ALL
SELECT 'master_course unique per (course_id, period_sortable)' AS metric,
       COUNT(*) AS rows,
       COUNT(*) - COUNT(DISTINCT (course_id, period_sortable)) AS violations
FROM master_course;

-- DQ: per-term master_section grain and row-count conservation. source_rows uses
-- the exact population predicate from per_section above; encoded_term_violations
-- confirms that the period carried on each materialized row agrees with the period
-- suffix embedded in section_id. All three violation columns should be zero.
WITH source_by_term AS (
    SELECT
        period_sortable,
        COUNT(DISTINCT section_id) AS source_rows,
        COUNT(*) AS source_catalog_rows,
        COUNT(*) FILTER (WHERE is_course_material_use) AS source_use_rows,
        COUNT(*) FILTER (WHERE is_course_material_no_use) AS source_no_use_rows
    FROM comprehensive_data
    WHERE section_id IS NOT NULL
      AND period_sortable IS NOT NULL
      AND period_date >= '2024-01-01'
    GROUP BY period_sortable
),
master_by_term AS (
    SELECT
        period_sortable,
        COUNT(*) AS master_rows,
        COUNT(DISTINCT section_id) AS unique_section_ids,
        COUNT(*) FILTER (
            WHERE REGEXP_EXTRACT(section_id, '::([0-9]{4}-[1-4])$', 1)
                  IS DISTINCT FROM period_sortable
        ) AS encoded_term_violations,
        SUM(course_material_use_count) AS master_use_rows,
        SUM(course_material_no_use_count) AS master_no_use_rows
    FROM master_section
    GROUP BY period_sortable
)
SELECT
    'master_section term grain/count conservation' AS metric,
    COALESCE(m.period_sortable, s.period_sortable) AS period_sortable,
    COALESCE(m.master_rows, 0) AS master_rows,
    COALESCE(s.source_rows, 0) AS source_rows,
    COALESCE(m.master_rows - m.unique_section_ids, 0) AS uniqueness_violations,
    COALESCE(m.encoded_term_violations, 0) AS encoded_term_violations,
    ABS(COALESCE(m.master_rows, 0) - COALESCE(s.source_rows, 0)) AS conservation_violations,
    COALESCE(s.source_catalog_rows, 0)
      - COALESCE(s.source_use_rows, 0)
      - COALESCE(s.source_no_use_rows, 0) AS source_partition_violations,
    ABS(COALESCE(m.master_use_rows, 0) - COALESCE(s.source_use_rows, 0))
        AS use_row_conservation_violations,
    ABS(COALESCE(m.master_no_use_rows, 0) - COALESCE(s.source_no_use_rows, 0))
        AS no_use_row_conservation_violations
FROM master_by_term m
FULL OUTER JOIN source_by_term s USING (period_sortable)
ORDER BY period_sortable;

-- Informational section-level population mix. Mixed sections retain their one
-- section/enrollment row while only their Use materials feed release metrics.
SELECT
    'master_section Use/NoUse mix (#58)' AS metric,
    period_sortable,
    COUNT(*) FILTER (
        WHERE course_material_use_count > 0 AND course_material_no_use_count = 0
    ) AS use_only_sections,
    COUNT(*) FILTER (
        WHERE course_material_use_count = 0 AND course_material_no_use_count > 0
    ) AS no_use_only_sections,
    COUNT(*) FILTER (
        WHERE course_material_use_count > 0 AND course_material_no_use_count > 0
    ) AS mixed_sections
FROM master_section
GROUP BY period_sortable
ORDER BY period_sortable;

-- DQ (informational, #24): mode() flattens source-noise divergence. Run one
-- fixed-state aggregate per field; seven simultaneous COUNT(DISTINCT) maps over
-- 23.6M groups can exhaust memory after an otherwise successful rebuild.
SELECT 'section descriptive divergence (course_subject)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT section_id
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND section_id IS NOT NULL AND period_sortable IS NOT NULL
    GROUP BY section_id
    HAVING MIN(course_subject) IS DISTINCT FROM MAX(course_subject)
);

SELECT 'section descriptive divergence (course_number)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT section_id
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND section_id IS NOT NULL AND period_sortable IS NOT NULL
    GROUP BY section_id
    HAVING MIN(course_number) IS DISTINCT FROM MAX(course_number)
);

SELECT 'section descriptive divergence (course_title)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT section_id
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND section_id IS NOT NULL AND period_sortable IS NOT NULL
    GROUP BY section_id
    HAVING MIN(course_title) IS DISTINCT FROM MAX(course_title)
);

SELECT 'section descriptive divergence (course_level)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT section_id
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND section_id IS NOT NULL AND period_sortable IS NOT NULL
    GROUP BY section_id
    HAVING MIN(course_level) IS DISTINCT FROM MAX(course_level)
);

SELECT 'section descriptive divergence (school)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT section_id
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND section_id IS NOT NULL AND period_sortable IS NOT NULL
    GROUP BY section_id
    HAVING MIN(school) IS DISTINCT FROM MAX(school)
);

SELECT 'section descriptive divergence (section)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT section_id
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND section_id IS NOT NULL AND period_sortable IS NOT NULL
    GROUP BY section_id
    HAVING MIN(section) IS DISTINCT FROM MAX(section)
);

SELECT 'section descriptive divergence (department)' AS note,
       COUNT(*) AS divergent_sections
FROM (
    SELECT section_id
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND section_id IS NOT NULL AND period_sortable IS NOT NULL
    GROUP BY section_id
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

-- Supply exclusion summary (informational, #36): supply is audited over all rows;
-- the final column is sections that carry supply rows but have no Use material.
SELECT 'supply exclusion (sections)' AS note,
       COUNT(*) FILTER (WHERE is_supply) AS sections_with_supply,
       SUM(supply_count)                 AS supply_materials,
       COUNT(*) FILTER (WHERE is_supply AND material_count = 0) AS supply_no_use_sections
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
