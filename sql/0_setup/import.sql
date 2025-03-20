-- Import CSV files into DuckDB tables
-- This file uses variables that will be substituted by the shell script

-- Extract table names from filenames (lowercase, no extension)
-- These will be set by the shell script before running this SQL
-- Example: bayview_20241211, hdic_dist_2022_selected, master_optout

-- Drop existing tables if they exist
DROP TABLE IF EXISTS ${SURVEY_TABLE};
DROP TABLE IF EXISTS ${IPEDS_TABLE};
DROP TABLE IF EXISTS ${OPTOUT_TABLE};

-- Import survey data
CREATE TABLE ${SURVEY_TABLE} AS
SELECT *
FROM read_csv('${SURVEY_CSV}',
    compression='gzip',
    header=true,
    delim=',',
    quote='"',
    escape='"',
    nullstr=['N/A', '', 'Not applicable']);

-- Import IPEDS data
CREATE TABLE ${IPEDS_TABLE} AS
SELECT *
FROM read_csv('${IPEDS_CSV}', 
    header=true, 
    delim=',', 
    nullstr=['N/A', '', 'Not applicable']);

-- Import opt-out data
CREATE TABLE ${OPTOUT_TABLE} AS
SELECT *
FROM read_csv('${OPTOUT_CSV}', 
    header=true, 
    delim=',', 
    nullstr=['N/A', '', 'Not applicable']);

-- Create unversioned views of the latest tables
-- First drop any existing objects with these names (tables or views)
DROP VIEW IF EXISTS survey_data;
DROP VIEW IF EXISTS ipeds_data;
DROP VIEW IF EXISTS optout_data;
DROP TABLE IF EXISTS survey_data;
DROP TABLE IF EXISTS ipeds_data;
DROP TABLE IF EXISTS optout_data;

-- Create views that point to the versioned tables
CREATE VIEW survey_data AS SELECT * FROM ${SURVEY_TABLE};
CREATE VIEW ipeds_data AS SELECT * FROM ${IPEDS_TABLE};
CREATE VIEW optout_data AS SELECT * FROM ${OPTOUT_TABLE};
