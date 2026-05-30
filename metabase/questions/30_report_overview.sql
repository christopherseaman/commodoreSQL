-- name: Report — Section / OER / IA Overview
-- display: table
-- description: Sections, institutions, and OER/IA adoption over the selected filters. Filters live on the dashboard.

SELECT
    COUNT(DISTINCT comprehensive_data.section_id) AS sections,
    COUNT(DISTINCT unit_id) AS institutions,
    ROUND(100.0 * COUNT(DISTINCT comprehensive_data.section_id) FILTER (WHERE is_oer) / NULLIF(COUNT(DISTINCT comprehensive_data.section_id), 0), 2) AS pct_oer_sections,
    ROUND(100.0 * COUNT(DISTINCT comprehensive_data.section_id) FILTER (WHERE is_ia)  / NULLIF(COUNT(DISTINCT comprehensive_data.section_id), 0), 2) AS pct_ia_sections
FROM comprehensive_data
LEFT JOIN state_region ON comprehensive_data.state = state_region.state
WHERE period_date >= '2024-01-01'
  [[ AND {{state}} ]]
  [[ AND {{region}} ]]
  [[ AND {{unit_id}} ]]
  [[ AND {{control}} ]]
  [[ AND {{iclevel}} ]]
  [[ AND {{instsize}} ]]
  [[ AND {{enroll_24}} ]]
  [[ AND {{dist_enroll_24}} ]]
  [[ AND {{course_level}} ]]
  [[ AND {{course_subject}} ]]
  [[ AND {{course_id}} ]]
  [[ AND {{period_sortable}} ]]
  [[ AND {{material}} ]]
