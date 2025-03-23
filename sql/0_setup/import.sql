-- Configure memory and performance settings
SET memory_limit='8GB';
SET temp_directory='./tmp';
SET threads=4;

-- Import CSV files into DuckDB tables
-- This file uses variables that will be substituted by the shell script

BEGIN TRANSACTION;

-- Drop existing tables if they exist
DROP TABLE IF EXISTS ${SURVEY_TABLE};
DROP TABLE IF EXISTS ${IPEDS_TABLE};
DROP TABLE IF EXISTS ${OPTOUT_TABLE};

-- Import survey data
CREATE TABLE ${SURVEY_TABLE} AS
SELECT * FROM read_csv('${SURVEY_CSV}',
    compression='gzip',
    header=true,
    delim=',',
    quote='"',
    escape='"',
    nullstr=['N/A', '', 'Not applicable']);

-- Convert numeric fields to appropriate types
ALTER TABLE ${SURVEY_TABLE} ALTER "Enrollments" TYPE INTEGER USING TRY_CAST("Enrollments" AS INTEGER);

-- Create indexes on survey data for joins
CREATE INDEX idx_survey_email ON ${SURVEY_TABLE}("E-Mail");
CREATE INDEX idx_survey_ipedid ON ${SURVEY_TABLE}("IPED ID");

-- Import IPEDS data
CREATE TABLE ${IPEDS_TABLE} AS
SELECT * FROM read_csv('${IPEDS_CSV}', 
    header=true, 
    delim=',', 
    nullstr=['N/A', '', 'Not applicable']);

-- Convert numeric fields to appropriate types
ALTER TABLE ${IPEDS_TABLE} ALTER sector TYPE INTEGER USING TRY_CAST(sector AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER iclevel TYPE INTEGER USING TRY_CAST(iclevel AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER control TYPE INTEGER USING TRY_CAST(control AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER instsize TYPE INTEGER USING TRY_CAST(instsize AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER efydetot_tot_22 TYPE INTEGER USING TRY_CAST(efydetot_tot_22 AS INTEGER);
ALTER TABLE ${IPEDS_TABLE} ALTER efyde_tot_22 TYPE INTEGER USING TRY_CAST(efyde_tot_22 AS INTEGER);

-- Create index on IPEDS data for joins
CREATE INDEX idx_ipeds_unitid ON ${IPEDS_TABLE}(unitid);

-- Import opt-out data
CREATE TABLE ${OPTOUT_TABLE} AS
SELECT * FROM read_csv('${OPTOUT_CSV}', 
    header=true, 
    delim=',', 
    nullstr=['N/A', '', 'Not applicable']);

-- Create index on opt-out data for joins
CREATE INDEX idx_optout_email ON ${OPTOUT_TABLE}(Emails);

-- Create unversioned views of the latest tables
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

COMMIT;

-- Run ANALYZE after commit to update statistics
ANALYZE ${SURVEY_TABLE};
ANALYZE ${IPEDS_TABLE};
ANALYZE ${OPTOUT_TABLE};
