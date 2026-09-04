-- name: DQ — Digital Rental Days Consistency
-- display: bar
-- description: Raw digital rentals grouped by section/ISBN; mixed NULL terms flagged. Within (section, isbn) digital rental groups: all-NULL and all-set are consistent (benign); mixed is real DQ (~0.04% of pairs).

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'digital_rental_days_consistency'
ORDER BY
    CASE metric_name
        WHEN 'pairs_with_digital_rental' THEN 1
        WHEN 'all_set_consistent'        THEN 2
        WHEN 'all_null_consistent'       THEN 3
        WHEN 'mixed_real_dq_issue'       THEN 4
    END
