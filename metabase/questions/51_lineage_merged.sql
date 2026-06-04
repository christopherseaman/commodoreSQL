-- name: Lineage 2 — Merged (catalog × IPEDS × OER/IA)
-- display: table
-- description: Merged record — catalog joined to IPEDS (control/level/size) + OER/IA classification + filter_include. Same school.
SELECT section_id, course_title, ISBN13, book_status, filter_include, is_oer, is_ia, control, level AS iclevel, size AS instsize, institution_name
FROM comprehensive_data
WHERE period_date >= '2024-01-01'
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, ISBN13
LIMIT 200
