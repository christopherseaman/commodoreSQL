-- name: Sections with No Included Materials (2024+)
-- display: table
-- description: Sections present in 2024+ data with zero rows passing the has_required filter — potential cross-listed or data-quality cases

SELECT DISTINCT
    c.section_id,
    c.course_id,
    c.school,
    c.department,
    c.course_number,
    c.section,
    c.course_title,
    c.period,
    c.period_date,
    s.has_required
FROM course_catalog_20251215 c
JOIN section_book_status s ON c.section_id = s.section_id
WHERE c.period_date >= '2024-01-01'
  AND c.section_id NOT IN (
      SELECT DISTINCT section_id
      FROM comprehensive_data
      WHERE filter_include = TRUE
  )
ORDER BY c.school, c.period_date DESC
