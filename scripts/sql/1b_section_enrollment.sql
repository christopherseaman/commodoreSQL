-- Complete valid 2024+ section spine and the established enrollment assignment
-- ladder. This helper intentionally reads the normalized source and IPEDS
-- directly; supply-aware section requiredness is computed in 2_oer_classification.

${CONFIG}

DROP TABLE IF EXISTS _se_base;
DROP TABLE IF EXISTS _se_course_level;
DROP TABLE IF EXISTS _se_signals;
DROP TABLE IF EXISTS _se_enriched;
DROP TABLE IF EXISTS _se_reference;
DROP TABLE IF EXISTS _se_course_agg;
DROP TABLE IF EXISTS _se_class_agg;
DROP TABLE IF EXISTS _se_level_agg;
DROP TABLE IF EXISTS section_enrollment;

CREATE TEMP TABLE _se_base AS
-- Requiredness is a row/material concern and is joined in comprehensive_data;
-- this helper remains independent of supply classification.
SELECT
    c.section_id,
    ANY_VALUE(c.course_id) AS course_id,
    ANY_VALUE(c.period_sortable) AS period_sortable,
    ANY_VALUE(i.control) AS control,
    ANY_VALUE(i.iclevel) AS level,
    ANY_VALUE(i.sector) AS sector,
    MAX(c.enrollments) AS enrollments,
    MAX(c.seats_taken) AS seats_taken,
    (MAX(c.enrollments) IS NOT NULL) AS has_enrollment,
    (MAX(c.seats_taken) IS NOT NULL AND MAX(c.seats_taken) < 9999)
        AS has_enrollment_own_seats
FROM ${SURVEY_TABLE} c
LEFT JOIN ${IPEDS_TABLE} i ON c.unit_id = i.unitid
WHERE c.section_id IS NOT NULL
  AND c.period_sortable IS NOT NULL
  AND c.period_date >= DATE '2024-01-01'
GROUP BY c.section_id;

CREATE TEMP TABLE _se_course_level AS
SELECT c.section_id, mode(c.course_level ORDER BY c.course_level) AS course_level
FROM ${SURVEY_TABLE} c
WHERE c.section_id IS NOT NULL
  AND c.period_sortable IS NOT NULL
  AND c.period_date >= DATE '2024-01-01'
GROUP BY c.section_id;

CREATE TEMP TABLE _se_signals AS
SELECT course_id, period_sortable,
    SUM(CASE WHEN has_enrollment THEN 1 ELSE 0 END) AS course_enroll_sections,
    SUM(CASE WHEN has_enrollment_own_seats THEN 1 ELSE 0 END) AS course_seats_sections
FROM _se_base
GROUP BY course_id, period_sortable;

CREATE TEMP TABLE _se_enriched AS
SELECT b.*, cl.course_level,
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
SELECT course_id, period_sortable,
    quantile_cont(enrollments, 0.5) AS course_enrollment_median,
    quantile_cont(CASE WHEN seats_taken < 9999 THEN seats_taken END, 0.5) AS course_seats_median
FROM _se_reference GROUP BY course_id, period_sortable;

CREATE TEMP TABLE _se_class_agg AS
SELECT control, level, period_sortable,
    quantile_cont(enrollments, 0.5) AS class_enrollment_median
FROM _se_reference GROUP BY control, level, period_sortable;

CREATE TEMP TABLE _se_level_agg AS
SELECT level, period_sortable, quantile_cont(enrollments, 0.5) AS level_enrollment_median
FROM _se_reference GROUP BY level, period_sortable;

DROP TABLE _se_reference;

CREATE TABLE section_enrollment AS
SELECT base.section_id, base.course_id, base.period_sortable, base.control, base.level,
    base.sector, base.course_level, base.enrollments, base.seats_taken,
    base.has_enrollment, base.has_enrollment_sibling,
    base.has_enrollment_own_seats, base.has_enrollment_sibling_seats,
    ROUND(COALESCE(base.enrollments, CASE WHEN base.seats_taken < 9999 THEN base.seats_taken END,
                   ca.course_enrollment_median, ca.course_seats_median,
                   cla.class_enrollment_median, lv.level_enrollment_median))::INT AS enrollment_assigned,
    CASE
        WHEN base.enrollments IS NOT NULL THEN 'own'
        WHEN base.seats_taken < 9999 THEN 'own_seats'
        WHEN ca.course_enrollment_median IS NOT NULL THEN 'sibling_enroll'
        WHEN ca.course_seats_median IS NOT NULL THEN 'sibling_seats'
        WHEN cla.class_enrollment_median IS NOT NULL THEN 'class_median'
        WHEN lv.level_enrollment_median IS NOT NULL THEN 'level_median'
        ELSE 'none'
    END AS enrollment_source
FROM _se_enriched base
LEFT JOIN _se_course_agg ca ON base.course_id = ca.course_id AND base.period_sortable = ca.period_sortable
LEFT JOIN _se_class_agg cla ON base.control = cla.control AND base.level = cla.level AND base.period_sortable = cla.period_sortable
LEFT JOIN _se_level_agg lv ON base.level = lv.level AND base.period_sortable = lv.period_sortable;

DROP TABLE _se_enriched;
DROP TABLE _se_course_agg;
DROP TABLE _se_class_agg;
DROP TABLE _se_level_agg;

SELECT 'section_enrollment grain/key DQ' AS metric, COUNT(*) AS rows,
    COUNT(*) - COUNT(DISTINCT section_id) AS duplicate_rows,
    COUNT(*) FILTER (WHERE section_id IS NULL OR period_sortable IS NULL) AS key_null_rows,
    COUNT(*) FILTER (WHERE has_enrollment IS DISTINCT FROM (enrollments IS NOT NULL)
       OR has_enrollment_own_seats IS DISTINCT FROM (seats_taken IS NOT NULL AND seats_taken < 9999)) AS raw_flag_violations,
    COUNT(*) FILTER (WHERE (enrollment_assigned IS NULL) <> (enrollment_source = 'none')) AS assignment_source_violations
FROM section_enrollment;

ANALYZE section_enrollment;
