-- Aggregate and transform records by faculty, course sections, and courses

${CONFIG}

-- section_cost: per-section cost aggregates over DISTINCT priced materials.
-- Required vs non-required uses the catalog classification (filter_include, #1).
-- Sums over distinct (section_id, ISBN13) materials that have a price; NULL-priced
-- materials contribute nothing (*_priced_count shows coverage). "owned" = buy-only
-- (rentals omitted), from pricing_wide.price_buy_min/max. Materialized as a TABLE so
-- master_section / master_course join it cheaply.
DROP TABLE IF EXISTS section_cost;
CREATE TABLE section_cost AS
WITH materials AS (
    SELECT
        c.section_id,
        MAX(c.course_id)       AS course_id,
        MAX(c.period_sortable) AS period_sortable,
        c.ISBN13,
        BOOL_OR(c.filter_include) AS is_required,
        MAX(pw.price_min)     AS price_min,
        MAX(pw.price_max)     AS price_max,
        MAX(pw.price_buy_min) AS owned_min,
        MAX(pw.price_buy_max) AS owned_max
    FROM comprehensive_data c
    LEFT JOIN pricing_wide pw
        ON c.section_id = pw.section_id AND c.ISBN13 = pw.isbn13
    WHERE c.period_date >= '2024-01-01'
        AND c.section_id IS NOT NULL
        AND c.period_sortable IS NOT NULL
        AND c.ISBN13 IS NOT NULL
    GROUP BY c.section_id, c.ISBN13
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
    COUNT(DISTINCT ISBN13) FILTER (WHERE is_required AND price_min IS NOT NULL)     AS required_priced_count,
    COUNT(DISTINCT ISBN13) FILTER (WHERE NOT is_required AND price_min IS NOT NULL) AS optional_priced_count
FROM materials
GROUP BY section_id;

-- Create master_section: exactly one row per section_id (2024+). Collapsed by section_id;
-- descriptive cols resolved via mode() (most-frequent) / ANY_VALUE (constant) / MAX (#24 —
-- see the divergence DQ at the bottom). Cost columns (#2/#3/#4) join 1:1 on section_id.
-- Materialized as a TABLE (not a VIEW): the course-sibling window + LIST(DISTINCT publisher)
-- aggregations are far too expensive to recompute per query — a single Metabase SELECT *
-- would re-derive the whole 23.5M-row window. Drop dependents first (they reference it).
DROP VIEW  IF EXISTS master_course_material;
DROP VIEW  IF EXISTS master_course;
DROP VIEW  IF EXISTS master_section;
DROP TABLE IF EXISTS master_section;
CREATE TABLE master_section AS
WITH per_section AS (
    SELECT
        section_id,
        -- course_id/period_sortable are substrings of section_id, and period/period_date
        -- derive deterministically from them -> constant per section_id (0 divergence,
        -- can't break by construction), so ANY_VALUE is exact (no DQ needed).
        ANY_VALUE(course_id)       AS course_id,
        ANY_VALUE(period)          AS period,
        ANY_VALUE(period_sortable) AS period_sortable,
        ANY_VALUE(period_date)     AS period_date,
        -- Institution enrichment (IPEDS + catalog state), keyed on unit_id -> constant per
        -- section_id (0 divergence verified across 2,428 units), so ANY_VALUE is exact.
        -- Carried through the collapse so master_section is the complete enriched section
        -- record and downstream filters (state / control / size ...) need no re-join.
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
        -- descriptive cols can diverge within a section_id (source-noise spelling /
        -- normalization variants, e.g. raw course_number "101" vs "0101" that normalize
        -- to one section_id); mode() keeps the most-frequent value. enrollments/seats_taken
        -- stay MAX. No columns dropped (#24).
        mode(school)               AS school,
        mode(department)           AS department,
        mode(course_number)        AS course_number,
        mode(section)              AS section,
        mode(course_title)         AS course_title,
        mode(course_level)         AS course_level,
        mode(course_subject)       AS course_subject,
        COUNT(*) AS material_count,
        -- required vs non-required reuses filter_include (the has_required fallback:
        -- 'required' rows, plus no-entry rows in sections with no required material).
        -- filter_include is never NULL, so the two FILTERs partition material_count.
        COUNT(*) FILTER (WHERE filter_include)     AS required_count,
        COUNT(*) FILTER (WHERE NOT filter_include) AS optional_count,
        -- OER / Inclusive-Access: indicator (any item) + item count, over ALL section
        -- materials. is_oer/is_ia come from comprehensive_data (FormatType lookup).
        -- COALESCE keeps the indicator boolean so is_oer <=> oer_count > 0.
        COALESCE(BOOL_OR(is_oer), FALSE) AS is_oer,
        COALESCE(BOOL_OR(is_ia),  FALSE) AS is_ia,
        COUNT(*) FILTER (WHERE is_oer) AS oer_count,
        COUNT(*) FILTER (WHERE is_ia)  AS ia_count,
        LIST(DISTINCT publisher) FILTER (WHERE publisher IS NOT NULL) AS publishers,
        -- required/optional publisher splits reuse filter_include (consistent with #1's
        -- required_count classification), not raw book_status='required'.
        LIST(DISTINCT publisher) FILTER (WHERE publisher IS NOT NULL AND filter_include) AS required_publishers,
        COUNT(DISTINCT publisher) FILTER (WHERE filter_include)     AS required_publisher_count,
        COUNT(DISTINCT publisher) FILTER (WHERE NOT filter_include) AS optional_publisher_count,
        MAX(enrollments) AS enrollments,
        MAX(seats_taken) AS seats_taken,
        -- Coverage (2026-06-04 notes): ISBN presence + OER/IA classifiability per section.
        -- is_oer/is_ia are NULL exactly when FormatType is absent, so has_formattype is the
        -- classifiability flag; the counts give the per-section coverage numerator.
        COALESCE(BOOL_OR(ISBN13 IS NOT NULL), FALSE)                              AS has_isbn,
        COALESCE(BOOL_OR("FormatType" IS NOT NULL AND "FormatType" <> ''), FALSE) AS has_formattype,
        COUNT(*) FILTER (WHERE ISBN13 IS NOT NULL)                                AS isbn_count,
        COUNT(*) FILTER (WHERE "FormatType" IS NOT NULL AND "FormatType" <> '')   AS classified_count,
        -- Enrollment fill-potential helpers (diagnostic only — values are NOT imputed).
        (MAX(enrollments) IS NOT NULL)                             AS own_has_enrollment,
        (MAX(seats_taken) IS NOT NULL AND MAX(seats_taken) < 9999) AS own_has_seats
    FROM comprehensive_data
    WHERE
        section_id IS NOT NULL AND
        period_sortable IS NOT NULL AND
        -- filter_include is gated on period_date >= 2024; scope the view to match so
        -- required_count (= filter_include count) is meaningful on every row.
        period_date >= '2024-01-01'
    GROUP BY section_id
),
with_course AS (
    -- Sibling context within the same (course_id, period_sortable): how many sibling
    -- sections carry enrollment / usable seats_taken, feeding the fill-potential flags.
    SELECT *,
        SUM(CASE WHEN own_has_enrollment THEN 1 ELSE 0 END) OVER w AS course_enroll_sections,
        SUM(CASE WHEN own_has_seats      THEN 1 ELSE 0 END) OVER w AS course_seats_sections
    FROM per_section
    WINDOW w AS (PARTITION BY course_id, period_sortable)
)
SELECT
    base.* EXCLUDE (own_has_enrollment, own_has_seats, course_enroll_sections, course_seats_sections),
    sc.required_cost_total_min, sc.required_cost_total_max,
    sc.optional_cost_total_min, sc.optional_cost_total_max,
    sc.required_cost_owned_min, sc.required_cost_owned_max,
    sc.optional_cost_owned_min, sc.optional_cost_owned_max,
    -- price_avg convention: (min + max) / 2, NOT an arithmetic mean (see CLAUDE.md)
    (sc.required_cost_total_min + sc.required_cost_total_max) / 2.0 AS required_cost_avg,
    (sc.required_cost_owned_min + sc.required_cost_owned_max) / 2.0 AS required_cost_owned_avg,
    (sc.optional_cost_total_min + sc.optional_cost_total_max) / 2.0 AS optional_cost_avg,
    sc.required_priced_count, sc.optional_priced_count
FROM (
    SELECT *,
        -- Four diagnostic flags (one section per row). fill_* are meaningful only when
        -- enrollment is missing; each marks a distinct signal that COULD fill it.
        own_has_enrollment                                      AS has_enrollment,
        (NOT own_has_enrollment AND course_enroll_sections > 0) AS fill_sibling_enrollment,
        (NOT own_has_enrollment AND own_has_seats)              AS fill_own_seats,
        (NOT own_has_enrollment
         AND (course_seats_sections - CASE WHEN own_has_seats THEN 1 ELSE 0 END) > 0) AS fill_sibling_seats
    FROM with_course
) base
LEFT JOIN section_cost sc ON base.section_id = sc.section_id;

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
    period_date >= '2024-01-01'
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

-- DQ: required_count + optional_count must reconcile to material_count on every
-- row (the issue #1 invariant: filter_include partitions materials into
-- required vs non-required). Both rows should report violations = 0; a nonzero
-- value signals a classification regression.
SELECT 'master_section reconciliation' AS metric,
       COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE required_count + optional_count <> material_count) AS violations
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
SELECT 'master_section unique per section_id' AS metric,
       COUNT(*) AS rows,
       COUNT(*) - COUNT(DISTINCT section_id) AS violations
FROM master_section
UNION ALL
SELECT 'master_course unique per (course_id, period_sortable)' AS metric,
       COUNT(*) AS rows,
       COUNT(*) - COUNT(DISTINCT (course_id, period_sortable)) AS violations
FROM master_course;

-- DQ (informational, #24): descriptive-column divergence flattened by the section
-- collapse — mode() keeps the most-frequent value per section_id. Nonzero is expected
-- source noise, not an error; this surfaces which field is noisy and how many sections.
SELECT 'section descriptive divergence (flattened)' AS note,
       COUNT(*) FILTER (WHERE n_subject > 1) AS course_subject,
       COUNT(*) FILTER (WHERE n_cnum > 1)    AS course_number,
       COUNT(*) FILTER (WHERE n_title > 1)   AS course_title,
       COUNT(*) FILTER (WHERE n_level > 1)   AS course_level,
       COUNT(*) FILTER (WHERE n_school > 1)  AS school,
       COUNT(*) FILTER (WHERE n_section > 1) AS section,
       COUNT(*) FILTER (WHERE n_dept > 1)    AS department
FROM (
    SELECT section_id,
           COUNT(DISTINCT course_subject) AS n_subject,
           COUNT(DISTINCT course_number)  AS n_cnum,
           COUNT(DISTINCT course_title)   AS n_title,
           COUNT(DISTINCT course_level)   AS n_level,
           COUNT(DISTINCT school)         AS n_school,
           COUNT(DISTINCT section)        AS n_section,
           COUNT(DISTINCT department)     AS n_dept
    FROM comprehensive_data
    WHERE period_date >= '2024-01-01' AND section_id IS NOT NULL AND period_sortable IS NOT NULL
    GROUP BY section_id
);

-- Coverage summary (informational, 2026-06-04 notes). Values are NOT imputed; these
-- quantify how much of the missing-enrollment gap COULD be filled from each signal, and
-- how many materials are ISBN'd / OER-IA-classifiable. fill_* flags overlap (a section can
-- be fillable from more than one signal), so they do not sum to (missing - unfillable).
SELECT 'enrollment fill-potential (sections)' AS note,
       COUNT(*) FILTER (WHERE has_enrollment)          AS has_enrollment,
       COUNT(*) FILTER (WHERE NOT has_enrollment)      AS missing,
       COUNT(*) FILTER (WHERE fill_sibling_enrollment) AS fill_sibling_enroll,
       COUNT(*) FILTER (WHERE fill_own_seats)          AS fill_own_seats,
       COUNT(*) FILTER (WHERE fill_sibling_seats)      AS fill_sibling_seats,
       COUNT(*) FILTER (WHERE NOT has_enrollment AND NOT fill_sibling_enrollment
                          AND NOT fill_own_seats AND NOT fill_sibling_seats) AS unfillable
FROM master_section;

SELECT 'OER/IA + ISBN coverage' AS note,
       COUNT(*) FILTER (WHERE has_isbn)       AS sections_with_isbn,
       COUNT(*) FILTER (WHERE has_formattype) AS sections_with_classified,
       SUM(isbn_count)       AS isbn_materials,
       SUM(classified_count) AS classified_materials
FROM master_section;
