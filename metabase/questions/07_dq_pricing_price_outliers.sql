-- name: DQ — Pricing Boundaries & Availability
-- display: bar
-- description: Deduplicated pricing observations at zero, sentinel, and outlier boundaries, plus wide rows lacking price bounds. Bookstores often use $0 as a placeholder; prices above $1000 are unusual. Missing wide bounds can be legitimate for sentinel-only groups and are an availability metric, not a zero-invariant failure.

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'price_outliers'
    OR (check_id = 'price_avg_sanity' AND metric_name = 'rows_with_null_bounds')
ORDER BY
    CASE metric_name
        WHEN 'price_null'      THEN 1
        WHEN 'price_zero'      THEN 2
        WHEN 'price_under_1'   THEN 3
        WHEN 'price_over_1000' THEN 4
        WHEN 'rows_with_null_bounds' THEN 5
    END
