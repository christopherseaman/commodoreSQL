-- name: Required Materials Price by Subject (Recent)
-- display: table
-- description: Master Section required price bounds by course subject; buy-priced subset for purchase-only. Each subject-level midpoint is recomputed from that subject's minimum and maximum section bounds. Price coverage remains an arithmetic mean of priced-material counts per section.

SELECT
    course_subject,
    COUNT(*)                                AS sections,
    ROUND((MIN(required_price_min) + MAX(required_price_max)) / 2.0, 2)
                                             AS required_price_midrange,
    ROUND((MIN(required_price_buy_min) + MAX(required_price_buy_max)) / 2.0, 2)
                                             AS required_buy_price_midrange,
    ROUND(MIN(required_price_min), 2)       AS required_price_min,
    ROUND(MAX(required_price_max), 2)       AS required_price_max,
    ROUND(AVG(required_priced_count), 2)    AS avg_priced_materials
FROM master_section
WHERE required_price_avg IS NOT NULL
GROUP BY course_subject
ORDER BY required_price_midrange DESC NULLS LAST
