-- name: Lineage 7 — Master Course (rollup)
-- display: table
-- description: Master Course rollups across material-bearing sections for selected school. enrollment_total sums raw reported section enrollment; assigned enrollment remains on master_section. Includes totals, OER/IA, coverage, and cost (MIN/MAX/AVG). Set the School (unit_id) filter.
SELECT *
FROM master_course
WHERE 1=1
  [[ AND split_part(course_id, '::', 1) = {{unit_id}} ]]
ORDER BY course_id
LIMIT 200
