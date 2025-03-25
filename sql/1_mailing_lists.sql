-- Step 1: Create Mailing Lists
-- This script creates:
-- 1. Master mailing list (deduplicated)
-- 2. Recent mailing list (last 8 periods)
-- 3. State-specific mailing lists
-- 4. Texas time series

-- Create master mailing list
DROP TABLE IF EXISTS master_mailing;
CREATE TABLE master_mailing AS
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
DROP TABLE IF EXISTS recent_periods;
CREATE TABLE recent_periods AS
SELECT DISTINCT period_sortable
FROM master_mailing
ORDER BY period_sortable DESC
LIMIT 8;

-- Create recent mailing list (last 2 years / 8 periods)
DROP TABLE IF EXISTS recent_mailing;
CREATE TABLE recent_mailing AS
SELECT m.*
FROM master_mailing m
JOIN recent_periods p ON m.period_sortable = p.period_sortable;

-- Create state-specific mailing lists
DROP TABLE IF EXISTS california_mailing;
CREATE TABLE california_mailing AS
SELECT * FROM recent_mailing WHERE State = 'CA';

DROP TABLE IF EXISTS texas_mailing;
CREATE TABLE texas_mailing AS
SELECT * FROM recent_mailing WHERE State = 'TX';

DROP TABLE IF EXISTS florida_mailing;
CREATE TABLE florida_mailing AS
SELECT * FROM recent_mailing WHERE State = 'FL';

DROP TABLE IF EXISTS newyork_mailing;
CREATE TABLE newyork_mailing AS
SELECT * FROM recent_mailing WHERE State = 'NY';

-- Create Texas time series (all Fall terms)
DROP TABLE IF EXISTS texas_fall_series;
CREATE TABLE texas_fall_series AS
SELECT *
FROM comprehensive_data
WHERE 
    State = 'TX' AND
    Period LIKE 'Fall %'; 