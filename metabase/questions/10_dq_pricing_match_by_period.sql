-- name: DQ — Pricing → Catalog Match Rate by Period
-- display: line
-- description: Percent of pricing rows whose (section_id, isbn13) is found in catalog, by period. Drops here flag schema/format drift.

SELECT period_sortable, match_pct, pricing_rows, rows_matched
FROM __data_quality_pricing_match_by_period
WHERE 1 = 1
[[ AND {{period_sortable}} ]]
ORDER BY period_sortable
