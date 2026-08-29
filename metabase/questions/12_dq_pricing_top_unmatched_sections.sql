-- name: DQ — Top Unmatched Pricing Section Cohorts
-- display: table
-- description: Top (unit_id, period) cohorts by raw pricing sections with no exact section_id match in comprehensive_data. The DQ snapshot compares all source pricing sections; no inferred-required or canonical-Use filter is applied.

SELECT unit_id, period_sortable, pricing_sections, unmatched, unmatched_pct
FROM __data_quality_top_unmatched_pricing_sections
ORDER BY unmatched DESC
