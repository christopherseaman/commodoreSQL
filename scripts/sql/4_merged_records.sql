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

-- Create master_section: one row per section per period (2024+).
-- Cost columns (#2/#3/#4) come from section_cost, attached at section_id grain; on
-- the ~0.13% of section_ids that split into >1 row they repeat (read via the key).
DROP VIEW IF EXISTS master_section;
CREATE VIEW master_section AS
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
FROM (
    SELECT
        section_id,
        course_id,
        period,
        period_sortable,
        period_date,
        school,
        department,
        course_number,
        section,
        course_title,
        course_level,
        course_subject,
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
        LIST(DISTINCT publisher) FILTER (WHERE publisher IS NOT NULL AND LOWER(book_status) = 'required') AS required_publishers,
        COUNT(DISTINCT CASE WHEN LOWER(book_status) = 'required' THEN publisher END) AS required_publisher_count,
        COUNT(DISTINCT CASE WHEN LOWER(book_status) != 'required' THEN publisher END) AS optional_publisher_count,
        MAX(enrollments) AS enrollments,
        MAX(seats_taken) AS seats_taken
    FROM comprehensive_data
    WHERE
        section_id IS NOT NULL AND
        period_sortable IS NOT NULL AND
        -- filter_include is gated on period_date >= 2024; scope the view to match so
        -- required_count (= filter_include count) is meaningful on every row.
        period_date >= '2024-01-01'
    GROUP BY
        section_id,
        course_id,
        period,
        period_sortable,
        period_date,
        school,
        department,
        course_number,
        section,
        course_title,
        course_level,
        course_subject
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
        period,
        period_sortable,
        period_date,
        school,
        department,
        course_number,
        course_title,
        course_level,
        course_subject,
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
        LIST(publishers) FILTER (WHERE publishers IS NOT NULL) AS all_publishers,
        SUM(required_publisher_count) AS unique_required_publishers
    FROM master_section
    GROUP BY
        course_id,
        period,
        period_sortable,
        period_date,
        school,
        department,
        course_number,
        course_title,
        course_level,
        course_subject
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
FROM master_section;
