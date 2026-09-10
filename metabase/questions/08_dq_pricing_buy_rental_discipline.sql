-- name: DQ — Pricing Buy/Rental Discipline
-- display: bar
-- description: Deduplicated pricing observations with option/rental-term inconsistencies. Source-data integrity for book_option and rental_days in the latest pricing snapshot. Buy rows should not have rental_days; rentals should, among other rules.

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'buy_rental_discipline'
ORDER BY metric_value DESC
