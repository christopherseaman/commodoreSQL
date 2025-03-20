-- Build comprehensive database
-- Merge survey data with IPEDS and opt-out data
-- Create date field in YYYY-N format

-- Drop existing tables if they exist
DROP TABLE IF EXISTS survey_data_prepared;
DROP TABLE IF EXISTS survey_with_ipeds;
DROP TABLE IF EXISTS comprehensive_data;

-- Step 1: Add period_sortable field to survey data
CREATE TABLE survey_data_prepared AS
SELECT *,
    CASE
        WHEN Period LIKE 'Winter %' THEN substr(Period, -4) || '-1'
        WHEN Period LIKE 'Spring %' THEN substr(Period, -4) || '-2'
        WHEN Period LIKE 'Summer %' THEN substr(Period, -4) || '-3'
        WHEN Period LIKE 'Fall %' THEN substr(Period, -4) || '-4'
        ELSE NULL
    END AS period_sortable
FROM survey_data;

-- Step 2: Join with IPEDS data
CREATE TABLE survey_with_ipeds AS
SELECT s.*,
    i.instnm,
    i.sector,
    i.iclevel,
    i.control,
    i.instsize,
    i.efydetot_tot_22,
    i.efyde_tot_22,
    i.typeinst,
    i.insttype
FROM survey_data_prepared s
LEFT JOIN ipeds_data i
ON s."IPED ID" = i.unitid;

-- Step 3: Join with opt-out data
CREATE TABLE comprehensive_data AS
SELECT s.*,
    CASE WHEN o.Emails IS NOT NULL THEN 1 ELSE 0 END AS is_opted_out,
    o.Source AS opt_out_source
FROM survey_with_ipeds s
LEFT JOIN optout_data o
ON LOWER(TRIM(s."E-Mail")) = LOWER(TRIM(o.Emails));
