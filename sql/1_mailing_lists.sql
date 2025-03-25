-- Step 1: Create Mailing Lists
-- This script creates:
-- 1. Master mailing list (deduplicated)
-- 2. Recent mailing list (last 8 periods)
-- 3. State-specific mailing lists
-- 4. Texas time series

-- Create master mailing list view
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
    period_sortable DESC,  -- Most recent date first
    "Enrollments" DESC,    -- Largest enrollment next
    RANDOM();             -- Random selection for ties

-- Get the 8 most recent periods
DROP VIEW IF EXISTS recent_periods;
CREATE VIEW recent_periods AS
SELECT DISTINCT period_sortable
FROM master_mailing
ORDER BY period_sortable DESC
LIMIT 8;

-- Create recent mailing list (last 2 years / 8 periods)
DROP VIEW IF EXISTS recent_mailing;
CREATE VIEW recent_mailing AS
SELECT m.*
FROM master_mailing m
JOIN recent_periods p ON m.period_sortable = p.period_sortable;

-- Create state-specific mailing lists
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

-- Create Texas time series (all Fall terms)
DROP VIEW IF EXISTS texas_fall_series;
CREATE VIEW texas_fall_series AS
SELECT *
FROM comprehensive_data
WHERE 
    State = 'TX' AND
    Period LIKE 'Fall %';
