-- Add OER (Open Educational Resources) and IA (Inclusive Access) classification
-- Both OER and IA status are derived from FormatType column via lookup table

BEGIN TRANSACTION;

-- Import format type classification lookup table
DROP TABLE IF EXISTS format_type_classification;
CREATE TABLE format_type_classification AS
SELECT
    format_type AS FormatType,
    is_oer::BOOLEAN AS is_oer,
    oer_category,
    is_ia::BOOLEAN AS is_ia,
    ia_category
FROM read_csv('${LOOKUP_DIR}/format_type_lookup.tsv',
    delim='\t',
    header=true,
    columns={
        'format_type': 'VARCHAR',
        'is_oer': 'VARCHAR',
        'oer_category': 'VARCHAR',
        'is_ia': 'VARCHAR',
        'ia_category': 'VARCHAR'
    }
);

-- Validate FormatType coverage before processing
-- Check for non-empty FormatTypes that aren't in the lookup table
DROP TABLE IF EXISTS data_quality_unmatched_formats;
CREATE TABLE data_quality_unmatched_formats AS
SELECT DISTINCT c.FormatType, COUNT(*) as record_count
FROM course_catalog_20251215 c
LEFT JOIN format_type_classification f ON c.FormatType = f.FormatType
WHERE c.FormatType IS NOT NULL
  AND c.FormatType != ''
  AND f.FormatType IS NULL
GROUP BY c.FormatType;

-- Display unmatched formats (if any exist, this will show them in pipeline output)
SELECT
    'WARNING: Unmatched FormatTypes found' AS validation_status,
    COUNT(*) as unmatched_format_count,
    SUM(record_count) as affected_records
FROM data_quality_unmatched_formats;

SELECT FormatType, record_count
FROM data_quality_unmatched_formats
ORDER BY record_count DESC;

-- Add OER and IA fields to comprehensive_data table
-- Note: comprehensive_data was created as a table in 0_setup.sql, so we need to recreate it
DROP TABLE IF EXISTS comprehensive_data;
CREATE TABLE comprehensive_data AS
SELECT
    c.*,
    -- Add OER classification from lookup table (NULL if no match)
    f.is_oer AS is_oer,
    COALESCE(f.oer_category, 'unknown') AS oer_category,
    -- Add IA (Inclusive Access) classification from lookup table (NULL if no match)
    f.is_ia AS is_ia,
    COALESCE(f.ia_category, 'unknown') AS ia_category,
    -- IPEDS data
    i.instnm AS institution_name,
    i.sector AS sector,
    i.iclevel AS level,
    i.control AS control,
    i.instsize AS size,
    i.enroll_24 AS enrollment_2024,
    i.dist_enroll_24 AS distance_enrollment_2024,
    i.inst_type AS institution_type,
    -- Panel data
    p.response_year AS panel_response_year,
    -- Opt-out data
    CASE WHEN oo.email IS NOT NULL THEN true ELSE false END AS is_opted_out,
    'opt_out' AS opt_out_source
FROM course_catalog_20251215 c
LEFT JOIN format_type_classification f ON c.FormatType = f.FormatType
LEFT JOIN ipeds_data i ON c.unit_id = i.unitid
LEFT JOIN panel p ON c.email = p.email
LEFT JOIN opt_out oo ON c.email = oo.email;

-- Validation: Check distribution of OER/IA classifications including NULLs
SELECT
    'OER/IA Distribution Check' AS validation_status,
    is_oer,
    is_ia,
    COUNT(*) as record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percent
FROM comprehensive_data
GROUP BY is_oer, is_ia
ORDER BY record_count DESC;

COMMIT;
