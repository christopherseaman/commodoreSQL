-- Complete recent-term catalog section spine and raw enrollment signals.
--
-- Reference-cohort eligibility and enrollment assignment belong to the
-- enrichment stage, where their context is consumed. This helper intentionally
-- retains no external-reference or supply dependency.

${CONFIG}

DROP TABLE IF EXISTS _se_base;
DROP TABLE IF EXISTS _se_course_level;
DROP TABLE IF EXISTS _se_signals;
DROP TABLE IF EXISTS _se_enriched;
DROP TABLE IF EXISTS section_enrollment;

CREATE TEMP TABLE _se_base AS
SELECT
    c.section_id,
    ANY_VALUE(c.unit_id)::BIGINT AS unit_id,
    ANY_VALUE(c.course_id) AS course_id,
    ANY_VALUE(c.period_sortable) AS period_sortable,
    MAX(c.enrollments) AS enrollments,
    MAX(c.seats_taken) AS seats_taken,
    (MAX(c.enrollments) IS NOT NULL) AS has_enrollment,
    (MAX(c.seats_taken) IS NOT NULL AND MAX(c.seats_taken) < 9999)
        AS has_enrollment_own_seats
FROM ${SURVEY_TABLE} c
WHERE c.section_id IS NOT NULL
  AND c.period_sortable IS NOT NULL
  AND c.period_sortable IN (SELECT period_sortable FROM recent_period)
GROUP BY c.section_id;

CREATE TEMP TABLE _se_course_level AS
SELECT c.section_id, mode(c.course_level ORDER BY c.course_level) AS course_level
FROM ${SURVEY_TABLE} c
WHERE c.section_id IS NOT NULL
  AND c.period_sortable IS NOT NULL
  AND c.period_sortable IN (SELECT period_sortable FROM recent_period)
GROUP BY c.section_id;

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

CREATE TABLE section_enrollment AS
SELECT
    section_id,
    unit_id,
    course_id,
    period_sortable,
    course_level,
    enrollments,
    seats_taken,
    has_enrollment,
    has_enrollment_sibling,
    has_enrollment_own_seats,
    has_enrollment_sibling_seats
FROM _se_enriched;

DROP TABLE _se_enriched;

SELECT
    'section_enrollment grain/key DQ' AS metric,
    COUNT(*) AS rows,
    COUNT(*) - COUNT(DISTINCT section_id) AS duplicate_rows,
    COUNT(*) FILTER (WHERE section_id IS NULL OR period_sortable IS NULL) AS key_null_rows,
    COUNT(*) FILTER (
        WHERE has_enrollment IS DISTINCT FROM (enrollments IS NOT NULL)
           OR has_enrollment_own_seats IS DISTINCT FROM (seats_taken IS NOT NULL AND seats_taken < 9999)
    ) AS raw_flag_violations
FROM section_enrollment;

ANALYZE section_enrollment;
