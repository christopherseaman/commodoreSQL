-- name: DQ — Pricing Price Outliers
-- display: bar
-- description: Raw pricing rows at zero, sentinel, and outlier boundaries. Row counts at price boundaries — bookstores often use $0 as placeholder; > $1000 is unusual

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'price_outliers'
ORDER BY
    CASE metric_name
        WHEN 'price_null'      THEN 1
        WHEN 'price_zero'      THEN 2
        WHEN 'price_under_1'   THEN 3
        WHEN 'price_over_1000' THEN 4
    END
