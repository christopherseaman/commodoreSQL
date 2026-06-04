-- name: Lineage 7 — Master Course (rollup)
-- display: table
-- description: Course-level rollup across sections — section count, totals, OER/IA, cost (MIN/MAX/AVG). Same school.
SELECT course_id, course_title, section_count, total_materials, total_required, is_oer, is_ia, required_cost_avg, required_cost_total_min, required_cost_total_max
FROM master_course
WHERE 1=1
  [[ AND split_part(course_id, '::', 1) = {{unit_id}} ]]
ORDER BY course_id
LIMIT 200
