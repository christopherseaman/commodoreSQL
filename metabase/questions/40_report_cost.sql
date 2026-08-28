-- name: Report — Materials Cost Summary
-- display: table
-- description: Canonical-Use required/optional materials cost over material-bearing sections (per-section, 2024+). Material status optionally restricts to sections carrying a matching material_costs item. Same dashboard filters as the overview.

SELECT
    COUNT(*) AS sections,
    ROUND(AVG(required_cost_avg), 2)       AS avg_required_cost,
    ROUND(AVG(required_cost_owned_avg), 2) AS avg_required_owned_cost,
    ROUND(AVG(optional_cost_avg), 2)       AS avg_optional_cost,
    ROUND(MIN(required_cost_total_min), 2) AS min_required_cost,
    ROUND(MAX(required_cost_total_max), 2) AS max_required_cost
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
      SELECT DISTINCT material_costs.section_id
      FROM material_costs
      WHERE {{material}}
  ) ]]
