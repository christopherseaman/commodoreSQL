-- Generate univariate frequency summaries for categorical variables
-- Creates summary views for data exploration and quality checking

${CONFIG}

BEGIN TRANSACTION;

-- FormatType frequency distribution
DROP VIEW IF EXISTS summary_formattype;
CREATE VIEW summary_formattype AS
SELECT
    COALESCE(FormatType, '(empty/NULL)') AS format_type,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT unit_id) AS institutions_using,
    COUNT(DISTINCT section_id) AS sections_using,
    SUM(CASE WHEN book_status = 'Required' THEN 1 ELSE 0 END) AS required_count,
    SUM(CASE WHEN book_status = 'Recommended' THEN 1 ELSE 0 END) AS recommended_count,
    SUM(CASE WHEN book_status = 'Option' THEN 1 ELSE 0 END) AS option_count
FROM comprehensive_data
GROUP BY FormatType
ORDER BY record_count DESC;

-- Book Status frequency distribution
DROP VIEW IF EXISTS summary_book_status;
CREATE VIEW summary_book_status AS
SELECT
    COALESCE(book_status, '(empty/NULL)') AS book_status,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT course_id) AS courses,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
GROUP BY book_status
ORDER BY record_count DESC;

-- State frequency distribution
DROP VIEW IF EXISTS summary_state;
CREATE VIEW summary_state AS
SELECT
    COALESCE(state, '(empty/NULL)') AS state,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT email) AS instructors,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT course_id) AS courses,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
GROUP BY state
ORDER BY record_count DESC;

-- Period frequency distribution
DROP VIEW IF EXISTS summary_period;
CREATE VIEW summary_period AS
SELECT
    period,
    period_sortable,
    period_date,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT course_id) AS courses,
    COUNT(DISTINCT email) AS instructors,
    COUNT(DISTINCT unit_id) AS institutions,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
WHERE period IS NOT NULL
GROUP BY period, period_sortable, period_date
ORDER BY period_sortable DESC;

-- OER classification summary
DROP VIEW IF EXISTS summary_oer;
CREATE VIEW summary_oer AS
SELECT
    is_oer,
    oer_category,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections_using,
    COUNT(DISTINCT course_id) AS courses_using,
    COUNT(DISTINCT unit_id) AS institutions_using,
    SUM(CASE WHEN book_status = 'Required' THEN 1 ELSE 0 END) AS required_count,
    SUM(CASE WHEN book_status = 'Recommended' THEN 1 ELSE 0 END) AS recommended_count
FROM comprehensive_data
GROUP BY is_oer, oer_category
ORDER BY record_count DESC;

-- IA (Inclusive Access) classification summary
DROP VIEW IF EXISTS summary_ia;
CREATE VIEW summary_ia AS
SELECT
    is_ia,
    ia_category,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections_using,
    COUNT(DISTINCT course_id) AS courses_using,
    COUNT(DISTINCT unit_id) AS institutions_using,
    SUM(CASE WHEN book_status = 'Required' THEN 1 ELSE 0 END) AS required_count,
    SUM(CASE WHEN book_status = 'Recommended' THEN 1 ELSE 0 END) AS recommended_count
FROM comprehensive_data
GROUP BY is_ia, ia_category
ORDER BY record_count DESC;

-- Institution sector summary (IPEDS)
DROP VIEW IF EXISTS summary_sector;
CREATE VIEW summary_sector AS
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
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
GROUP BY sector
ORDER BY record_count DESC;

-- Institution control summary (IPEDS)
DROP VIEW IF EXISTS summary_control;
CREATE VIEW summary_control AS
SELECT
    control,
    CASE control
        WHEN 1 THEN 'Public'
        WHEN 2 THEN 'Private not-for-profit'
        WHEN 3 THEN 'Private for-profit'
        ELSE 'Unknown/NULL'
    END AS control_description,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
GROUP BY control
ORDER BY record_count DESC;

-- Institution level summary (IPEDS)
DROP VIEW IF EXISTS summary_level;
CREATE VIEW summary_level AS
SELECT
    level,
    CASE level
        WHEN 1 THEN '4-year or above'
        WHEN 2 THEN '2-year but less than 4-year'
        WHEN 3 THEN 'Less than 2-year'
        ELSE 'Unknown/NULL'
    END AS level_description,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT unit_id) AS institutions,
    COUNT(DISTINCT section_id) AS sections,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
GROUP BY level
ORDER BY record_count DESC;

-- Course level summary
DROP VIEW IF EXISTS summary_course_level;
CREATE VIEW summary_course_level AS
SELECT
    COALESCE(course_level, '(empty/NULL)') AS course_level,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT course_id) AS courses,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
GROUP BY course_level
ORDER BY record_count DESC;

-- Course subject summary (top 50)
DROP VIEW IF EXISTS summary_course_subject;
CREATE VIEW summary_course_subject AS
SELECT
    COALESCE(course_subject, '(empty/NULL)') AS course_subject,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT course_id) AS courses,
    SUM(enrollments) AS total_enrollments,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
GROUP BY course_subject
ORDER BY record_count DESC
LIMIT 50;

-- Publisher summary (top 50)
DROP VIEW IF EXISTS summary_publisher;
CREATE VIEW summary_publisher AS
SELECT
    COALESCE(Publisher, '(empty/NULL)') AS publisher,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    COUNT(DISTINCT section_id) AS sections_using,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count,
    SUM(CASE WHEN book_status = 'Required' THEN 1 ELSE 0 END) AS required_count
FROM comprehensive_data
GROUP BY Publisher
ORDER BY record_count DESC
LIMIT 50;

-- Format summary
DROP VIEW IF EXISTS summary_format;
CREATE VIEW summary_format AS
SELECT
    COALESCE(Format, '(empty/NULL)') AS format,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percent_of_total,
    COUNT(DISTINCT ISBN13) AS unique_materials,
    SUM(CASE WHEN is_oer THEN 1 ELSE 0 END) AS oer_count,
    SUM(CASE WHEN is_ia THEN 1 ELSE 0 END) AS ia_count
FROM comprehensive_data
GROUP BY Format
ORDER BY record_count DESC;

COMMIT;
