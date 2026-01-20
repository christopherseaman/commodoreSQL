-- Generate targeted mailing lists from comprehensive data

${CONFIG}

-- Create deduplicated master mailing list
DROP VIEW IF EXISTS master_mailing;
CREATE VIEW master_mailing AS
SELECT DISTINCT ON ("E-Mail") *
FROM comprehensive_data
WHERE 
    "E-Mail" IS NOT NULL AND 
    "E-Mail" != '' AND
    is_opted_out = 0
ORDER BY 
    "E-Mail",
    period_sortable DESC,  -- Prioritize most recent data
    "Enrollments" DESC,    -- Then largest enrollment
    RANDOM();             -- Randomize remaining ties

-- Identify most recent periods for recent mailing list
DROP VIEW IF EXISTS recent_periods;
CREATE VIEW recent_periods AS
SELECT DISTINCT period_sortable
FROM master_mailing
ORDER BY period_sortable DESC
LIMIT 8;

-- Create recent mailing list (last 2 years)
DROP VIEW IF EXISTS recent_mailing;
CREATE VIEW recent_mailing AS
SELECT m.*
FROM master_mailing m
JOIN recent_periods p ON m.period_sortable = p.period_sortable;

-- Generate state-specific mailing lists
DROP VIEW IF EXISTS california_mailing;
CREATE VIEW california_mailing AS
SELECT * FROM recent_mailing WHERE State = 'CA';

DROP VIEW IF EXISTS texas_mailing;
CREATE VIEW texas_mailing AS
SELECT * FROM recent_mailing WHERE State = 'TX';

DROP VIEW IF EXISTS florida_mailing;
CREATE VIEW florida_mailing AS
SELECT * FROM recent_mailing WHERE State = 'FL';

DROP VIEW IF EXISTS newyork_mailing;
CREATE VIEW newyork_mailing AS
SELECT * FROM recent_mailing WHERE State = 'NY';

-- Create Texas Fall term time series
DROP VIEW IF EXISTS texas_fall_series;
CREATE VIEW texas_fall_series AS
SELECT *
FROM comprehensive_data
WHERE 
    State = 'TX' AND
    Period LIKE 'Fall %';
