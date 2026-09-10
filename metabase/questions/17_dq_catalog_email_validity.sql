-- name: DQ — Email Validity
-- display: bar
-- description: Inferred-required recent-term catalog rows with email anomalies. Catalog rows with email anomalies. email_null is dominated by source nulls; the others are leaks from cleaning.

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'email_validity'
ORDER BY metric_value DESC
