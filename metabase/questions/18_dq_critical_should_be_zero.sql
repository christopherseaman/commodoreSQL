-- name: DQ — Critical Metrics (should be 0)
-- display: table
-- description: Pricing grain/pivot/price-bound and catalog classification regression checks. Headline indicators that must remain at 0. Non-zero values here mean a regression in dedupe, pivot, bounds, or classification logic; expected missing-bound availability is reported separately.

SELECT category, check_id, metric_name, metric_value
FROM __data_quality_metrics
WHERE
    (check_id = 'residual_grain' AND metric_name = 'unexplained_residual')
    OR (check_id = 'tall_vs_wide_parity' AND metric_name = 'difference')
    OR (check_id = 'price_avg_sanity' AND metric_name IN ('rows_below_min', 'rows_above_max'))
    OR (check_id = 'classification_consistency' AND metric_name IN ('oer_inconsistent_pairs', 'ia_inconsistent_pairs'))
ORDER BY category, check_id, metric_name
