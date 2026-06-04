-- name: Lineage 1 — Raw Catalog (BMG course materials)
-- display: table
-- description: Original BMG course-material rows for the selected school (one per material listing). Set the School (unit_id) filter.
SELECT section_id, course_title, section, ISBN13, Title, Publisher, FormatType, book_status, enrollments
FROM course_catalog_20251215
WHERE period_date >= '2024-01-01'
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, ISBN13
LIMIT 200
