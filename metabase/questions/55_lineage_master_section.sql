-- name: Lineage 6 — Master Section (wide record)
-- display: table
-- description: The wide course-section record — material counts, OER/IA, and cost columns per section. Same school.
SELECT section_id, course_title, material_count, required_count, optional_count, is_oer, is_ia, required_cost_avg, required_cost_owned_avg, optional_cost_avg, enrollments
FROM master_section
WHERE 1=1
  [[ AND split_part(section_id, '::', 1) = {{unit_id}} ]]
ORDER BY section_id
LIMIT 200
