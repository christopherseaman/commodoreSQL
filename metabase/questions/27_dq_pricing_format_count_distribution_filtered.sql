-- name: DQ — Pricing Wide format_count Distribution (Filtered)
-- display: bar
-- description: format_count distribution over pricing_wide_filtered (the required / filter_include subset). Filtered counterpart of Q11 (which is over the full pricing_wide base).

SELECT format_count, COUNT(*) AS pricing_wide_rows
FROM pricing_wide_filtered
GROUP BY format_count
ORDER BY format_count
