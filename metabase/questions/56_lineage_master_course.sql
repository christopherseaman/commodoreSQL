-- name: Lineage 7 — Master Course (rollup)
-- display: table
-- description: Master Course rollups across material-bearing sections for selected school. Course-level rollup across sections — totals, OER/IA, coverage, cost (MIN/MAX/AVG). Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.
SELECT *
FROM master_course
WHERE 1=1
  [[ AND split_part(course_id, '::', 1) = {{unit_id}} ]]
ORDER BY course_id
LIMIT 200
