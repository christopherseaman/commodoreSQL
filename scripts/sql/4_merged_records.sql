-- Aggregate and transform records by faculty, course sections, and courses

${CONFIG}

-- Create master_section: one row per section per period
DROP VIEW IF EXISTS master_section;
CREATE VIEW master_section AS
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
    course_subject;

-- Create master_course: one row per course per period
DROP VIEW IF EXISTS master_course;
CREATE VIEW master_course AS
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
    course_subject;

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
FROM master_section;

