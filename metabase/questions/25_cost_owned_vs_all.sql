-- name: Buy vs All-Options Required Price by Course Level (Recent)
-- display: bar
-- description: Master Section required prices by level; buy-priced subset for purchase-only. Each course-level midpoint is recomputed from that level's minimum and maximum section bounds, comparing all options (including rental) with buy-only prices.

SELECT
    COALESCE(course_level, '(none)')        AS course_level,
    COUNT(*)                                AS sections,
    ROUND((MIN(required_price_min) + MAX(required_price_max)) / 2.0, 2)
                                             AS all_options_price_midrange,
    ROUND((MIN(required_price_buy_min) + MAX(required_price_buy_max)) / 2.0, 2)
                                             AS buy_price_midrange
FROM master_section
WHERE required_price_avg IS NOT NULL
GROUP BY course_level
ORDER BY all_options_price_midrange DESC
