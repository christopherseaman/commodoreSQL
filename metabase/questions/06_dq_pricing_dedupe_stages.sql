-- name: DQ — Pricing Import Row Summary
-- display: bar
-- description: Imported pricing rows before and after deduplication. Shows raw CSV rows, the total removed by deduplication, and final deduplicated latest-snapshot observations; it does not expose intermediate stages.

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
