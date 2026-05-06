-- name: DQ — Pricing Wide format_count Distribution
-- display: bar
-- description: How many of the 18 (option × condition × format) pivot cells are populated per (section, isbn). 0 means NULL-option only; 1 most common; long tail is rich data.

SELECT format_count, pricing_wide_rows
FROM __data_quality_format_count_distribution
ORDER BY format_count
