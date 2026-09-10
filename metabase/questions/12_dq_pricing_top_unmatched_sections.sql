-- name: DQ — Top Unmatched Pricing Section Cohorts
-- display: table
-- description: Deduplicated pricing sections lacking exact catalog matches, by institution/term. Top (unit_id, period) cohorts in the latest pricing snapshot with no exact section_id match in comprehensive_data. No inferred-required or canonical-Use filter is applied.

SELECT unit_id, period_sortable, pricing_sections, unmatched, unmatched_pct
FROM __data_quality_top_unmatched_pricing_sections
ORDER BY unmatched DESC
