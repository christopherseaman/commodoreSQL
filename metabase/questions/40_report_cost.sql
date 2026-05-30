-- name: Report — Materials Cost Summary
-- display: table
-- description: Required/optional materials cost (per-section, 2024+) over the selected sections. Same dashboard filters as the overview.

SELECT
    COUNT(*) AS sections,
    ROUND(AVG(required_cost_avg), 2)       AS avg_required_cost,
    ROUND(AVG(required_cost_owned_avg), 2) AS avg_required_owned_cost,
    ROUND(AVG(optional_cost_avg), 2)       AS avg_optional_cost,
    ROUND(MIN(required_cost_total_min), 2) AS min_required_cost,
    ROUND(MAX(required_cost_total_max), 2) AS max_required_cost
FROM master_section
WHERE section_id IN (
    SELECT DISTINCT comprehensive_data.section_id
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
)
