-- name: Report — Section / OER / IA Overview
-- display: table
-- description: Sections, institutions, and OER/IA adoption over the selected filters (state, control, course level/subject, term). Filters live on the dashboard.

SELECT
    COUNT(DISTINCT section_id) AS sections,
    COUNT(DISTINCT unit_id)    AS institutions,
    ROUND(100.0 * COUNT(DISTINCT section_id) FILTER (WHERE is_oer) / NULLIF(COUNT(DISTINCT section_id), 0), 2) AS pct_oer_sections,
    ROUND(100.0 * COUNT(DISTINCT section_id) FILTER (WHERE is_ia)  / NULLIF(COUNT(DISTINCT section_id), 0), 2) AS pct_ia_sections
FROM comprehensive_data
WHERE period_date >= '2024-01-01'
  [[ AND {{state}} ]]
  [[ AND {{control}} ]]
  [[ AND {{course_level}} ]]
  [[ AND {{course_subject}} ]]
  [[ AND {{period_sortable}} ]]
