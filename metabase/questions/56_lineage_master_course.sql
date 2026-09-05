-- name: Lineage 7 — Master Course (draft)
-- display: table
-- description: Draft course/term rollups for selected school. Definition pending. Raw enrollment is summed; assigned enrollment remains on master_section.
SELECT *
FROM master_course
WHERE 1=1
  [[ AND split_part(course_id, '::', 1) = {{unit_id}} ]]
ORDER BY course_id
LIMIT 200
