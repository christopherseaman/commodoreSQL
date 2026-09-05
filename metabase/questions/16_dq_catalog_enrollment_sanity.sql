-- name: DQ — Enrollment Sanity
-- display: bar
-- description: Inferred-required recent-term catalog rows with enrollment/seat anomalies. Catalog rows with anomalous enrollment vs seats_taken. Negative=bad data; sentinel 9999=uncapped courses; small/medium/large overage = real over-enrollment.

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'enrollment_sanity'
ORDER BY
    CASE metric_name
        WHEN 'enrollments_negative'      THEN 1
        WHEN 'seats_taken_sentinel_9999' THEN 2
        WHEN 'overage_small_1_to_5'      THEN 3
        WHEN 'overage_medium_6_to_100'   THEN 4
        WHEN 'overage_large_over_100'    THEN 5
    END
