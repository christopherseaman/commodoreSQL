-- name: DQ — Top Unmatched Pricing Sections (filter_include=FALSE)
-- display: table
-- description: Top (unit_id, period) combinations where pricing has many sections that don't appear in catalog. filter_include=TRUE always matches; this surfaces pre-2024/non-required formatting drift.

SELECT unit_id, period_sortable, pricing_sections, unmatched, unmatched_pct
FROM __data_quality_top_unmatched_pricing_sections
ORDER BY unmatched DESC
