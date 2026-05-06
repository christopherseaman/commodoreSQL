-- name: DQ — Pricing Buy/Rental Discipline
-- display: bar
-- description: Source-data integrity for book_option, rental_days. Buy rows shouldn't have rental_days; rentals should — among other rules.

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'buy_rental_discipline'
ORDER BY metric_value DESC
