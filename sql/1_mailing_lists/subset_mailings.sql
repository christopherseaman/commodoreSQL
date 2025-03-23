-- Create subset mailing lists
-- Filter master list for recent records and by state
-- Using CTEs for better readability and performance

-- Drop existing tables if they exist
DROP TABLE IF EXISTS recent_periods;
DROP TABLE IF EXISTS recent_mailing;
DROP TABLE IF EXISTS california_mailing;
DROP TABLE IF EXISTS texas_mailing;
DROP TABLE IF EXISTS florida_mailing;
DROP TABLE IF EXISTS newyork_mailing;
DROP TABLE IF EXISTS texas_fall_series;

-- Get the 8 most recent periods
CREATE TABLE recent_periods AS
SELECT DISTINCT period_sortable
FROM master_mailing
ORDER BY period_sortable DESC
LIMIT 8;

-- Create recent records mailing list (last 2 years / 8 periods)
CREATE TABLE recent_mailing AS
SELECT m.*
FROM master_mailing m
JOIN recent_periods p ON m.period_sortable = p.period_sortable;

-- Create state-specific mailing lists
-- California mailing list
CREATE TABLE california_mailing AS
SELECT * FROM recent_mailing WHERE State = 'CA';

-- Texas mailing list
CREATE TABLE texas_mailing AS
SELECT * FROM recent_mailing WHERE State = 'TX';

-- Florida mailing list
CREATE TABLE florida_mailing AS
SELECT * FROM recent_mailing WHERE State = 'FL';

-- New York mailing list
CREATE TABLE newyork_mailing AS
SELECT * FROM recent_mailing WHERE State = 'NY';

-- Create Texas time series (all Fall terms)
CREATE TABLE texas_fall_series AS
SELECT *
FROM comprehensive_data
WHERE 
    State = 'TX' AND
    Period LIKE 'Fall %';

-- Create indexes on state mailing lists for potential future use
CREATE INDEX idx_california_mailing_email ON california_mailing("E-Mail");
CREATE INDEX idx_texas_mailing_email ON texas_mailing("E-Mail");
CREATE INDEX idx_florida_mailing_email ON florida_mailing("E-Mail");
CREATE INDEX idx_newyork_mailing_email ON newyork_mailing("E-Mail");
