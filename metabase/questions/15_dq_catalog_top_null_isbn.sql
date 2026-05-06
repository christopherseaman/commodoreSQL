-- name: DQ — Top Schools by NULL ISBN
-- display: table
-- description: Top schools with NULL ISBN13 in the catalog — typically large research universities that don't systematically report ISBNs.

SELECT school, null_isbn_rows, distinct_sections
FROM __data_quality_top_null_isbn_schools
ORDER BY null_isbn_rows DESC
