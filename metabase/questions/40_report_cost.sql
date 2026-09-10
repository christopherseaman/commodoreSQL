-- name: Report — Materials Price Summary
-- display: table
-- description: Material-bearing recent-term sections under report filters; canonical required/all-material prices. Each report-level midpoint is recomputed from the selected sections' minimum and maximum bounds. Material status optionally restricts to sections carrying a matching master_material item. Same dashboard filters as the overview.

SELECT
    COUNT(*) AS sections,
    ROUND((MIN(required_price_min) + MAX(required_price_max)) / 2.0, 2)
                                            AS required_price_midrange,
    ROUND((MIN(required_price_buy_min) + MAX(required_price_buy_max)) / 2.0, 2)
                                            AS required_buy_price_midrange,
    ROUND((MIN(all_price_min) + MAX(all_price_max)) / 2.0, 2)
                                            AS all_material_price_midrange,
    ROUND(MIN(required_price_min), 2)      AS selected_section_required_price_min,
    ROUND(MAX(required_price_max), 2)      AS selected_section_required_price_max
FROM master_section
LEFT JOIN state_region ON master_section.state = state_region.state
WHERE TRUE
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
