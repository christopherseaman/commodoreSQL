-- name: DQ — Pricing Wide format_count Distribution
-- display: bar
-- description: Pricing-wide pairs by offered buy/rental tuple count, regardless of price validity. Counts distinct option × condition × format tuples per section/ISBN; zero means no buy/rental tuple.

SELECT format_count, pricing_wide_rows
FROM __data_quality_format_count_distribution
ORDER BY format_count
