-- name: DQ — Top Schools by NULL ISBN
-- display: table
-- description: Inferred-required recent-term catalog rows; NULL-ISBN percentage per school. Top schools with NULL ISBN13 in the catalog. null_pct shows what proportion of that school's rows are missing an ISBN.

SELECT school, null_isbn_rows, non_null_isbn_rows, total_rows, null_pct, distinct_sections
FROM __data_quality_top_null_isbn_schools
ORDER BY null_isbn_rows DESC
