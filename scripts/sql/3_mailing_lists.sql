-- Generate targeted mailing lists from comprehensive data

${CONFIG}

-- Create deduplicated master mailing list
DROP VIEW IF EXISTS master_mailing;
CREATE VIEW master_mailing AS
SELECT DISTINCT ON (email)
    unit_id,
    school,
    state,
    department,
    course_level,
    course_subject,
    period,
    period_sortable,
    period_date,
    instructor,
    first_name,
    last_name,
    email
FROM comprehensive_data
WHERE
    email IS NOT NULL AND
    email != '' AND
    is_opted_out = false
ORDER BY
    email,
    period_sortable DESC,
    enrollments DESC,
    RANDOM();

-- Identify most recent periods for current mailing list
DROP VIEW IF EXISTS recent_periods;
CREATE VIEW recent_periods AS
SELECT DISTINCT period_sortable
FROM comprehensive_data
WHERE period_sortable IS NOT NULL
ORDER BY period_sortable DESC
LIMIT 12;

-- Create current mailing list (last 3 years / 12 periods)
DROP VIEW IF EXISTS current_mailing;
CREATE VIEW current_mailing AS
SELECT
    m.*,
    p.panel_response_year
FROM master_mailing m
LEFT JOIN (
    SELECT email, MAX(panel_response_year) AS panel_response_year
    FROM comprehensive_data
    WHERE panel_response_year IS NOT NULL
    GROUP BY email
) p ON m.email = p.email
WHERE m.period_sortable IN (SELECT period_sortable FROM recent_periods);

-- Generate state-specific mailing lists using State column from source data
DROP VIEW IF EXISTS current_mailing_ca;
CREATE VIEW current_mailing_ca AS
SELECT *
FROM current_mailing
WHERE state = 'CA';

DROP VIEW IF EXISTS current_mailing_tx;
CREATE VIEW current_mailing_tx AS
SELECT *
FROM current_mailing
WHERE state = 'TX';

DROP VIEW IF EXISTS current_mailing_fl;
CREATE VIEW current_mailing_fl AS
SELECT *
FROM current_mailing
WHERE state = 'FL';

DROP VIEW IF EXISTS current_mailing_ny;
CREATE VIEW current_mailing_ny AS
SELECT *
FROM current_mailing
WHERE state = 'NY';

DROP VIEW IF EXISTS current_mailing_other;
CREATE VIEW current_mailing_other AS
SELECT *
FROM current_mailing
WHERE state NOT IN ('CA', 'TX', 'FL', 'NY');
