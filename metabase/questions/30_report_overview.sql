-- name: Report — Section / OER / IA Overview
-- display: table
-- description: Material-bearing sections/institutions under selected report filters. Material-bearing sections and institutions, with canonical-Use OER/IA adoption, over the selected filters. Material status optionally restricts to sections carrying a matching master_material item. Filters live on the dashboard.

SELECT
    COUNT(*) AS sections,
    COUNT(DISTINCT master_section.unit_id) AS institutions,
    ROUND(100.0 * COUNT(*) FILTER (WHERE master_section.is_oer) / NULLIF(COUNT(*), 0), 2) AS pct_oer_sections,
    ROUND(100.0 * COUNT(*) FILTER (WHERE master_section.is_ia)  / NULLIF(COUNT(*), 0), 2) AS pct_ia_sections
FROM master_section
LEFT JOIN state_region ON master_section.state = state_region.state
WHERE master_section.period_date >= '2024-01-01'
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
  [[ AND master_section.section_id IN (
      SELECT DISTINCT master_material.section_id
      FROM master_material
      WHERE {{material}}
  ) ]]
