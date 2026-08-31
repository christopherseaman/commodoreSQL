-- Generate targeted mailing lists from the normalized course-material source.

${CONFIG}

-- Drop public projections before refreshing the persisted master selection.
DROP VIEW IF EXISTS current_mailing_ca;
DROP VIEW IF EXISTS current_mailing_tx;
DROP VIEW IF EXISTS current_mailing_fl;
DROP VIEW IF EXISTS current_mailing_ny;
DROP VIEW IF EXISTS current_mailing_pa;
DROP VIEW IF EXISTS current_mailing_can;
DROP VIEW IF EXISTS current_mailing_other;
DROP VIEW IF EXISTS current_mailing;
DROP VIEW IF EXISTS recent_periods;
-- Remove stale pre-#66 cache relations; they are no longer canonical outputs.
DROP TABLE IF EXISTS master_mailing_cache;
DROP TABLE IF EXISTS current_mailing_cache;
DROP TABLE IF EXISTS master_mailing;

-- Persist the deterministic selection once. FIRST ... ORDER BY is a grouped
-- top-one aggregate, avoiding the global DISTINCT ON sort while preserving the
-- exact documented ordering and a single coherent source row per email.
CREATE TABLE master_mailing AS
WITH selected AS (
    SELECT
        email,
        FIRST(
            struct_pack(
                unit_id := unit_id,
                school := school,
                state := state,
                department := department,
                course_level := course_level,
                course_subject := course_subject,
                period := period,
                period_sortable := period_sortable,
                period_date := period_date,
                instructor := instructor,
                first_name := first_name,
                last_name := last_name
            )
            ORDER BY
                period_sortable DESC NULLS LAST,
                enrollments DESC NULLS LAST,
                unit_id NULLS LAST,
                course_id NULLS LAST,
                section_id NULLS LAST,
                school NULLS LAST,
                state NULLS LAST,
                department NULLS LAST,
                course_level NULLS LAST,
                course_subject NULLS LAST,
                period NULLS LAST,
                period_date NULLS LAST,
                instructor NULLS LAST,
                first_name NULLS LAST,
                last_name NULLS LAST
        ) AS chosen
    FROM ${SURVEY_TABLE}
    WHERE
        email IS NOT NULL AND
        TRIM(email) != ''
    GROUP BY email
)
SELECT
    chosen.unit_id AS unit_id,
    chosen.school AS school,
    chosen.state AS state,
    chosen.department AS department,
    chosen.course_level AS course_level,
    chosen.course_subject AS course_subject,
    chosen.period AS period,
    chosen.period_sortable AS period_sortable,
    chosen.period_date AS period_date,
    chosen.instructor AS instructor,
    chosen.first_name AS first_name,
    chosen.last_name AS last_name,
    email
FROM selected;

-- Identify most recent periods for current mailing list
CREATE VIEW recent_periods AS
SELECT DISTINCT period_sortable
FROM master_mailing
WHERE period_sortable IS NOT NULL
ORDER BY period_sortable DESC
LIMIT 12;

-- Whiteboard Mailing Working population: recent selected catalog contacts,
-- excluding BVA opt-outs and LEFT-enriched with panel response history.
CREATE VIEW current_mailing AS
SELECT
    m.*,
    p.panel_response_year
FROM master_mailing m
LEFT JOIN panel_email p ON m.email = p.email
WHERE m.period_sortable IN (SELECT period_sortable FROM recent_periods)
  AND NOT EXISTS (
      SELECT 1
      FROM opt_out o
      WHERE o.email = m.email
  );

-- Generate pairwise-disjoint geographic mailing lists. Normalize only for
-- classification; retain the source state value in each exported row.
CREATE VIEW current_mailing_ca AS
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'CA';

CREATE VIEW current_mailing_tx AS
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'TX';

CREATE VIEW current_mailing_fl AS
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'FL';

CREATE VIEW current_mailing_ny AS
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'NY';

CREATE VIEW current_mailing_pa AS
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'PA';

CREATE VIEW current_mailing_can AS
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'CAN';

CREATE VIEW current_mailing_other AS
SELECT *
FROM current_mailing
WHERE COALESCE(UPPER(TRIM(state)), '')
      NOT IN ('CA', 'TX', 'FL', 'NY', 'PA', 'CAN');

-- One-line DQ: every current email must appear in exactly one geographic view.
WITH partitioned AS (
    SELECT email FROM current_mailing_ca
    UNION ALL SELECT email FROM current_mailing_tx
    UNION ALL SELECT email FROM current_mailing_fl
    UNION ALL SELECT email FROM current_mailing_ny
    UNION ALL SELECT email FROM current_mailing_pa
    UNION ALL SELECT email FROM current_mailing_can
    UNION ALL SELECT email FROM current_mailing_other
),
counts AS (
    SELECT
        (SELECT COUNT(*) FROM current_mailing) AS current_rows,
        (SELECT COUNT(DISTINCT email) FROM current_mailing) AS current_emails,
        COUNT(*) AS partition_rows,
        COUNT(DISTINCT email) AS partition_emails
    FROM partitioned
)
SELECT
    'current mailing geographic partition reconciliation' AS metric,
    current_rows,
    current_emails,
    partition_rows,
    partition_emails,
    current_rows = current_emails
      AND current_rows = partition_rows
      AND partition_rows = partition_emails AS is_match
FROM counts;
