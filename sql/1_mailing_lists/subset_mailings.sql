-- Create subset mailing lists
-- Filter master list for recent records and by state

-- Get the 8 most recent periods
CREATE TABLE IF NOT EXISTS recent_periods AS
SELECT DISTINCT period_sortable
FROM master_mailing
ORDER BY period_sortable DESC
LIMIT 8;

-- Create recent records mailing list (last 2 years / 8 periods)
CREATE TABLE IF NOT EXISTS recent_mailing AS
SELECT m.*
FROM master_mailing m
JOIN recent_periods p ON m.period_sortable = p.period_sortable;

-- Create California mailing list
CREATE TABLE IF NOT EXISTS california_mailing AS
SELECT *
FROM recent_mailing
WHERE State = 'CA';

-- Create Texas mailing list
CREATE TABLE IF NOT EXISTS texas_mailing AS
SELECT *
FROM recent_mailing
WHERE State = 'TX';

-- Create Florida mailing list
CREATE TABLE IF NOT EXISTS florida_mailing AS
SELECT *
FROM recent_mailing
WHERE State = 'FL';

-- Create New York mailing list
CREATE TABLE IF NOT EXISTS newyork_mailing AS
SELECT *
FROM recent_mailing
WHERE State = 'NY';

-- Create Texas time series (all Fall terms)
CREATE TABLE IF NOT EXISTS texas_fall_series AS
SELECT *
FROM comprehensive_data
WHERE 
    State = 'TX' AND
    Period LIKE 'Fall %';
