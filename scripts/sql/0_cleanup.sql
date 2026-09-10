-- Remove relations retired from the reporting surface before rebuilding IMPORT.
-- Explicit relation types keep this idempotent and prevent masking a type change.

${CONFIG}

BEGIN TRANSACTION;

-- Standalone legacy views
DROP VIEW IF EXISTS catalog_filtered;
DROP VIEW IF EXISTS course_records;
DROP VIEW IF EXISTS course_section_records;
DROP VIEW IF EXISTS faculty_records;
DROP VIEW IF EXISTS master_course_material;
DROP VIEW IF EXISTS recent_periods;
DROP VIEW IF EXISTS course_materials_post_2024;
DROP VIEW IF EXISTS course_material_post_2024;
DROP VIEW IF EXISTS course_materials_use;
DROP VIEW IF EXISTS course_materials_no_use;
DROP VIEW IF EXISTS course_materials_canada;
DROP VIEW IF EXISTS course_material_canada;
DROP VIEW IF EXISTS master_section_us_intro_fall2025;

-- Retired geographic projections; exports filter current_mailing directly.
DROP VIEW IF EXISTS current_mailing_ca;
DROP VIEW IF EXISTS current_mailing_tx;
DROP VIEW IF EXISTS current_mailing_fl;
DROP VIEW IF EXISTS current_mailing_ny;
DROP VIEW IF EXISTS current_mailing_pa;
DROP VIEW IF EXISTS current_mailing_can;
DROP VIEW IF EXISTS current_mailing_other;

-- Retired tables
DROP TABLE IF EXISTS data_quality_unmatched_formats;
DROP TABLE IF EXISTS email_issues;
DROP TABLE IF EXISTS section_book_status;
DROP TABLE IF EXISTS section_cost;
DROP TABLE IF EXISTS sample10_section_ids;
DROP TABLE IF EXISTS course_materials;
DROP TABLE IF EXISTS material_costs;
DROP TABLE IF EXISTS sample10pct_materials;

-- Retired univariate summary views
DROP VIEW IF EXISTS summary_book_status;
DROP VIEW IF EXISTS summary_control;
DROP VIEW IF EXISTS summary_course_level;
DROP VIEW IF EXISTS summary_course_subject;
DROP VIEW IF EXISTS summary_format;
DROP VIEW IF EXISTS summary_formattype;
DROP VIEW IF EXISTS summary_ia;
DROP VIEW IF EXISTS summary_level;
DROP VIEW IF EXISTS summary_oer;
DROP VIEW IF EXISTS summary_period;
DROP VIEW IF EXISTS summary_publisher;
DROP VIEW IF EXISTS summary_sector;
DROP VIEW IF EXISTS summary_state;

-- Retired crosstab summary views
DROP VIEW IF EXISTS crosstab_formattype_period;
DROP VIEW IF EXISTS crosstab_formattype_status;
DROP VIEW IF EXISTS crosstab_ia_period;
DROP VIEW IF EXISTS crosstab_ia_sector;
DROP VIEW IF EXISTS crosstab_ia_state;
DROP VIEW IF EXISTS crosstab_ia_status;
DROP VIEW IF EXISTS crosstab_oer_period;
DROP VIEW IF EXISTS crosstab_oer_sector;
DROP VIEW IF EXISTS crosstab_oer_state;
DROP VIEW IF EXISTS crosstab_oer_status;
DROP VIEW IF EXISTS crosstab_state_period;
DROP VIEW IF EXISTS crosstab_state_sector;
DROP VIEW IF EXISTS crosstab_status_period;
DROP VIEW IF EXISTS crosstab_subject_period;
DROP VIEW IF EXISTS crosstab_top_formats_period;
DROP VIEW IF EXISTS crosstab_formattype_oeria_period;
DROP VIEW IF EXISTS crosstab_formattype_oeria_status;
DROP VIEW IF EXISTS crosstab_formattype_oeria_sector;
DROP VIEW IF EXISTS crosstab_formattype_oeria_state;

-- Fail the transaction if any exact retired relation remains in the catalog.
SELECT CASE
    WHEN COUNT(*) = 0 THEN 'Legacy relation cleanup verified: 60 relations absent.'
    ELSE error('Legacy relation cleanup failed: retired relations remain.')
END AS cleanup_postcondition
FROM information_schema.tables
WHERE table_schema = 'main'
  AND table_name IN (
    'catalog_filtered', 'course_records', 'course_section_records', 'faculty_records',
    'master_course_material', 'recent_periods',
    'course_materials_post_2024', 'course_material_post_2024', 'course_materials_use',
    'course_materials_no_use', 'course_materials_canada', 'course_material_canada',
    'master_section_us_intro_fall2025',
    'current_mailing_ca', 'current_mailing_tx', 'current_mailing_fl',
    'current_mailing_ny', 'current_mailing_pa', 'current_mailing_can',
    'current_mailing_other',
    'data_quality_unmatched_formats', 'email_issues', 'section_book_status',
    'section_cost', 'sample10_section_ids',
    'course_materials', 'material_costs', 'sample10pct_materials',
    'summary_book_status', 'summary_control', 'summary_course_level',
    'summary_course_subject', 'summary_format', 'summary_formattype', 'summary_ia',
    'summary_level', 'summary_oer', 'summary_period', 'summary_publisher',
    'summary_sector', 'summary_state',
    'crosstab_formattype_period', 'crosstab_formattype_status',
    'crosstab_ia_period', 'crosstab_ia_sector', 'crosstab_ia_state',
    'crosstab_ia_status', 'crosstab_oer_period', 'crosstab_oer_sector',
    'crosstab_oer_state', 'crosstab_oer_status', 'crosstab_state_period',
    'crosstab_state_sector', 'crosstab_status_period', 'crosstab_subject_period',
    'crosstab_top_formats_period', 'crosstab_formattype_oeria_period',
    'crosstab_formattype_oeria_status', 'crosstab_formattype_oeria_sector',
    'crosstab_formattype_oeria_state'
);

COMMIT;
