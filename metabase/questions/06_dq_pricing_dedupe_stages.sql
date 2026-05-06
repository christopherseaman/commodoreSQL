-- name: DQ — Pricing Dedupe Stages
-- display: bar
-- description: Row counts at each dedupe stage in the pricing import (raw → byte-identical → multi-instructor → most-recent snapshot → final)

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'dedupe_stages'
ORDER BY
    CASE metric_name
        WHEN 'raw_csv_rows' THEN 1
        WHEN 'rows_removed_by_dedupe' THEN 2
        WHEN 'final_rows' THEN 3
        ELSE 9
    END
