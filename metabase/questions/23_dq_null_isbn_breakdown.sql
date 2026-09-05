-- name: DQ — Null ISBN Breakdown by Placeholder Type
-- display: table
-- description: Inferred-required recent-term catalog NULL-ISBN rows, by school/placeholder. Top schools by NULL ISBN, split by placeholder string. Globally only 3 placeholder values exist for NULL-ISBN rows — there are no genuinely-missing null-ISBN rows; "other" should always be 0. *No Book Details* (research/dissertation), *No Books Required* (explicit), *Bad Course* (DQ flag).

SELECT school, no_book_details, no_books_required, bad_course, other, total_null_isbn
FROM __data_quality_null_isbn_breakdown
ORDER BY total_null_isbn DESC
