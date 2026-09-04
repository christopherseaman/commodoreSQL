-- name: DQ — Top Schools Missing from IPEDS
-- display: table
-- description: Inferred-required 2024+ catalog rows at US institutions missing IPEDS. Top US schools whose unit_id isn't in IPEDS_2024 — typically closed/merged/consolidated institutions or sub-campuses tracked under main.

SELECT school, unit_id, catalog_rows
FROM __data_quality_top_unmatched_ipeds_schools
ORDER BY catalog_rows DESC
