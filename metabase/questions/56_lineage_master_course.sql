-- name: Lineage 7 — Master Course (rollup)
-- display: table
-- description: Course rollups for selected school. Raw enrollment is summed; assigned enrollment remains on master_section.
SELECT *
FROM master_course
WHERE 1=1
  [[ AND split_part(course_id, '::', 1) = {{unit_id}} ]]
ORDER BY course_id
LIMIT 200
