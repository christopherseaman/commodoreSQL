-- name: DQ — Pricing → Catalog Match Rate by Period
-- display: line
-- description: Deduplicated pricing observations by term; exact catalog section/ISBN match rate. Percent of latest-snapshot pricing observations whose (section_id, ISBN) is found in catalog, by period. Drops here flag schema or format drift.

SELECT period_sortable, match_pct, pricing_rows, rows_matched
FROM __data_quality_pricing_match_by_period
WHERE 1 = 1
[[ AND {{period_sortable}} ]]
ORDER BY period_sortable
