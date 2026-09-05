-- name: Required Materials Cost by Subject (Recent)
-- display: table
-- description: Master Section required costs per section; buy-priced subset for owned. Average required-material cost per section by course subject, with owned (buy-only) comparison and price coverage.

SELECT
    course_subject,
    COUNT(*)                                AS sections,
    ROUND(AVG(required_cost_avg), 2)        AS avg_required_cost,
    ROUND(AVG(required_cost_owned_avg), 2)  AS avg_required_owned_cost,
    ROUND(AVG(required_cost_total_min), 2)  AS avg_required_min,
    ROUND(AVG(required_cost_total_max), 2)  AS avg_required_max,
    ROUND(AVG(required_priced_count), 2)    AS avg_priced_materials
FROM master_section
WHERE required_cost_avg IS NOT NULL
GROUP BY course_subject
ORDER BY avg_required_cost DESC NULLS LAST
