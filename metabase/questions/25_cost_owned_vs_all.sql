-- name: Owned vs All-Options Cost by Course Level (2024+)
-- display: bar
-- description: Required-material cost — all options (incl. rental) vs owned (buy-only) — by course level. Owned reflects only materials that have a buy price.

SELECT
    COALESCE(course_level, '(none)')        AS course_level,
    COUNT(*)                                AS sections,
    ROUND(AVG(required_cost_avg), 2)        AS avg_all_options,
    ROUND(AVG(required_cost_owned_avg), 2)  AS avg_owned
FROM master_section
WHERE required_cost_avg IS NOT NULL
GROUP BY course_level
ORDER BY avg_all_options DESC
