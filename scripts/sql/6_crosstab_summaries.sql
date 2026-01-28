-- Generate cross-tabulation summaries for analyzing relationships
-- between categorical variables (FormatType, book_status, period, state, etc.)

${CONFIG}

BEGIN TRANSACTION;

-- FormatType × period_sortable (trends over time)
DROP VIEW IF EXISTS crosstab_formattype_period;
CREATE VIEW crosstab_formattype_period AS
SELECT
    COALESCE(FormatType, '(empty/NULL)') AS format_type,
    period_sortable,
    period_date,
    COUNT(*) AS record_count,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments,
    COUNT(DISTINCT unit_id) AS institutions
FROM comprehensive_data
WHERE period_sortable IS NOT NULL
GROUP BY FormatType, period_sortable, period_date
ORDER BY format_type, period_sortable, period_date DESC;

-- FormatType × book_status (required vs supplemental by format)
DROP VIEW IF EXISTS crosstab_formattype_status;
CREATE VIEW crosstab_formattype_status AS
SELECT
    COALESCE(FormatType, '(empty/NULL)') AS format_type,
    COALESCE(book_status, '(empty/NULL)') AS book_status,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY FormatType), 2) AS percent_within_format,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY FormatType, book_status
ORDER BY format_type, record_count DESC;

-- OER × book_status (OER required vs supplemental)
DROP VIEW IF EXISTS crosstab_oer_status;
CREATE VIEW crosstab_oer_status AS
SELECT
    is_oer,
    oer_category,
    COALESCE(book_status, '(empty/NULL)') AS book_status,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY is_oer), 2) AS percent_within_oer,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY is_oer, oer_category, book_status
ORDER BY is_oer DESC, record_count DESC;

-- IA × book_status (IA required vs supplemental)
DROP VIEW IF EXISTS crosstab_ia_status;
CREATE VIEW crosstab_ia_status AS
SELECT
    is_ia,
    ia_category,
    COALESCE(book_status, '(empty/NULL)') AS book_status,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY is_ia), 2) AS percent_within_ia,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY is_ia, ia_category, book_status
ORDER BY is_ia DESC, record_count DESC;

-- State × period_sortable (state trends over time)
DROP VIEW IF EXISTS crosstab_state_period;
CREATE VIEW crosstab_state_period AS
SELECT
    COALESCE(state, '(empty/NULL)') AS state,
    period_sortable,
    period_date,
    COUNT(*) AS record_count,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT email) AS instructors,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
WHERE period_sortable IS NOT NULL
GROUP BY state, period_sortable, period_date
ORDER BY state, period_sortable, period_date DESC;

-- OER × period_sortable (OER adoption trends)
DROP VIEW IF EXISTS crosstab_oer_period;
CREATE VIEW crosstab_oer_period AS
SELECT
    period_sortable,
    period_date,
    is_oer,
    oer_category,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY period_sortable), 2) AS percent_of_period,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT unit_id) AS institutions,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
WHERE period_sortable IS NOT NULL
GROUP BY period_sortable, period_date, is_oer, oer_category
ORDER BY period_sortable, period_date DESC, is_oer DESC, record_count DESC;

-- IA × period_sortable (IA adoption trends)
DROP VIEW IF EXISTS crosstab_ia_period;
CREATE VIEW crosstab_ia_period AS
SELECT
    period_sortable,
    period_date,
    is_ia,
    ia_category,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY period_sortable), 2) AS percent_of_period,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT unit_id) AS institutions,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
WHERE period_sortable IS NOT NULL
GROUP BY period_sortable, period_date, is_ia, ia_category
ORDER BY period_sortable, period_date DESC, is_ia DESC, record_count DESC;

-- State × sector (state distribution by institution type)
DROP VIEW IF EXISTS crosstab_state_sector;
CREATE VIEW crosstab_state_sector AS
SELECT
    COALESCE(state, '(empty/NULL)') AS state,
    sector,
    CASE sector
        WHEN 1 THEN 'Public, 4-year or above'
        WHEN 2 THEN 'Private not-for-profit, 4-year or above'
        WHEN 3 THEN 'Private for-profit, 4-year or above'
        WHEN 4 THEN 'Public, 2-year'
        WHEN 5 THEN 'Private not-for-profit, 2-year'
        WHEN 6 THEN 'Private for-profit, 2-year'
        WHEN 7 THEN 'Public, less than 2-year'
        WHEN 8 THEN 'Private not-for-profit, less than 2-year'
        WHEN 9 THEN 'Private for-profit, less than 2-year'
        ELSE 'Unknown/NULL'
    END AS sector_description,
    COUNT(*) AS record_count,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY state, sector
ORDER BY state, record_count DESC;

-- Course subject × period (subject trends over time - top 20 subjects)
DROP VIEW IF EXISTS crosstab_subject_period;
CREATE VIEW crosstab_subject_period AS
WITH top_subjects AS (
    SELECT course_subject
    FROM comprehensive_data
    WHERE course_subject IS NOT NULL
    GROUP BY course_subject
    ORDER BY COUNT(*) DESC
    LIMIT 20
)
SELECT
    course_subject,
    period_sortable,
    period_date,
    COUNT(*) AS record_count,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT course_id) AS courses,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
WHERE course_subject IN (SELECT course_subject FROM top_subjects)
    AND period_sortable IS NOT NULL
GROUP BY course_subject, period_sortable, period_date
ORDER BY course_subject, period_sortable, period_date DESC;

-- OER × state (OER adoption by state)
DROP VIEW IF EXISTS crosstab_oer_state;
CREATE VIEW crosstab_oer_state AS
SELECT
    COALESCE(state, '(empty/NULL)') AS state,
    is_oer,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY state), 2) AS percent_of_state,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY state, is_oer
ORDER BY state, is_oer DESC;

-- IA × state (IA adoption by state)
DROP VIEW IF EXISTS crosstab_ia_state;
CREATE VIEW crosstab_ia_state AS
SELECT
    COALESCE(state, '(empty/NULL)') AS state,
    is_ia,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY state), 2) AS percent_of_state,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY state, is_ia
ORDER BY state, is_ia DESC;

-- OER × sector (OER adoption by institution type)
DROP VIEW IF EXISTS crosstab_oer_sector;
CREATE VIEW crosstab_oer_sector AS
SELECT
    sector,
    CASE sector
        WHEN 1 THEN 'Public, 4-year or above'
        WHEN 2 THEN 'Private not-for-profit, 4-year or above'
        WHEN 3 THEN 'Private for-profit, 4-year or above'
        WHEN 4 THEN 'Public, 2-year'
        WHEN 5 THEN 'Private not-for-profit, 2-year'
        WHEN 6 THEN 'Private for-profit, 2-year'
        WHEN 7 THEN 'Public, less than 2-year'
        WHEN 8 THEN 'Private not-for-profit, less than 2-year'
        WHEN 9 THEN 'Private for-profit, less than 2-year'
        ELSE 'Unknown/NULL'
    END AS sector_description,
    is_oer,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY sector), 2) AS percent_of_sector,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY sector, is_oer
ORDER BY sector, is_oer DESC;

-- IA × sector (IA adoption by institution type)
DROP VIEW IF EXISTS crosstab_ia_sector;
CREATE VIEW crosstab_ia_sector AS
SELECT
    sector,
    CASE sector
        WHEN 1 THEN 'Public, 4-year or above'
        WHEN 2 THEN 'Private not-for-profit, 4-year or above'
        WHEN 3 THEN 'Private for-profit, 4-year or above'
        WHEN 4 THEN 'Public, 2-year'
        WHEN 5 THEN 'Private not-for-profit, 2-year'
        WHEN 6 THEN 'Private for-profit, 2-year'
        WHEN 7 THEN 'Public, less than 2-year'
        WHEN 8 THEN 'Private not-for-profit, less than 2-year'
        WHEN 9 THEN 'Private for-profit, less than 2-year'
        ELSE 'Unknown/NULL'
    END AS sector_description,
    is_ia,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY sector), 2) AS percent_of_sector,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY sector, is_ia
ORDER BY sector, is_ia DESC;

-- Book status × period (required vs supplemental trends)
DROP VIEW IF EXISTS crosstab_status_period;
CREATE VIEW crosstab_status_period AS
SELECT
    COALESCE(book_status, '(empty/NULL)') AS book_status,
    period_sortable,
    period_date,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY period_sortable), 2) AS percent_of_period,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
WHERE period_sortable IS NOT NULL
GROUP BY book_status, period_sortable, period_date
ORDER BY book_status, period_sortable, period_date DESC;

-- Top 10 FormatTypes × period (detailed format trends for most common types)
DROP VIEW IF EXISTS crosstab_top_formats_period;
CREATE VIEW crosstab_top_formats_period AS
WITH top_formats AS (
    SELECT FormatType
    FROM comprehensive_data
    WHERE FormatType IS NOT NULL AND FormatType != ''
    GROUP BY FormatType
    ORDER BY COUNT(*) DESC
    LIMIT 10
)
SELECT
    FormatType AS format_type,
    period_sortable,
    period_date,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY period_sortable), 2) AS percent_of_period,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
WHERE FormatType IN (SELECT FormatType FROM top_formats)
    AND period_sortable IS NOT NULL
GROUP BY FormatType, period_sortable, period_date
ORDER BY FormatType, period_sortable, period_date DESC;

-- FormatType × OER × IA × period (4-dimensional analysis over time)
DROP VIEW IF EXISTS crosstab_formattype_oeria_period;
CREATE VIEW crosstab_formattype_oeria_period AS
SELECT
    COALESCE(FormatType, '(empty/NULL)') AS format_type,
    is_oer,
    is_ia,
    period_sortable,
    period_date,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY period_sortable), 2) AS percent_of_period,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY FormatType, period_sortable), 2) AS percent_within_format_period,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT unit_id) AS institutions,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
WHERE period_sortable IS NOT NULL
GROUP BY FormatType, is_oer, is_ia, period_sortable, period_date
ORDER BY format_type, period_sortable, period_date DESC, is_oer DESC, is_ia DESC;

-- FormatType × OER × IA × book_status (4-dimensional analysis by status)
DROP VIEW IF EXISTS crosstab_formattype_oeria_status;
CREATE VIEW crosstab_formattype_oeria_status AS
SELECT
    COALESCE(FormatType, '(empty/NULL)') AS format_type,
    is_oer,
    is_ia,
    COALESCE(book_status, '(empty/NULL)') AS book_status,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY FormatType), 2) AS percent_within_format,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY book_status), 2) AS percent_within_status,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY FormatType, is_oer, is_ia, book_status
ORDER BY format_type, book_status, is_oer DESC, is_ia DESC;

-- FormatType × OER × IA × sector (4-dimensional analysis by institution type)
DROP VIEW IF EXISTS crosstab_formattype_oeria_sector;
CREATE VIEW crosstab_formattype_oeria_sector AS
SELECT
    COALESCE(FormatType, '(empty/NULL)') AS format_type,
    is_oer,
    is_ia,
    sector,
    CASE sector
        WHEN 1 THEN 'Public, 4-year or above'
        WHEN 2 THEN 'Private not-for-profit, 4-year or above'
        WHEN 3 THEN 'Private for-profit, 4-year or above'
        WHEN 4 THEN 'Public, 2-year'
        WHEN 5 THEN 'Private not-for-profit, 2-year'
        WHEN 6 THEN 'Private for-profit, 2-year'
        WHEN 7 THEN 'Public, less than 2-year'
        WHEN 8 THEN 'Private not-for-profit, less than 2-year'
        WHEN 9 THEN 'Private for-profit, less than 2-year'
        ELSE 'Unknown/NULL'
    END AS sector_description,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY FormatType, sector), 2) AS percent_within_format_sector,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY sector), 2) AS percent_within_sector,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY FormatType, is_oer, is_ia, sector
ORDER BY format_type, sector, is_oer DESC, is_ia DESC;

-- FormatType × OER × IA × state (4-dimensional analysis by state)
DROP VIEW IF EXISTS crosstab_formattype_oeria_state;
CREATE VIEW crosstab_formattype_oeria_state AS
SELECT
    COALESCE(FormatType, '(empty/NULL)') AS format_type,
    is_oer,
    is_ia,
    COALESCE(state, '(empty/NULL)') AS state,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY FormatType, state), 2) AS percent_within_format_state,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY state), 2) AS percent_within_state,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments
FROM comprehensive_data
GROUP BY FormatType, is_oer, is_ia, state
ORDER BY format_type, state, is_oer DESC, is_ia DESC;

COMMIT;
