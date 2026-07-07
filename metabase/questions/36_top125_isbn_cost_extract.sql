-- name: Top-125 ISBN Cost Extract — Fall 2025 (institution × course × faculty)
-- display: table
-- description: One row per Fall-2025 (period 2025-4) section-adoption of the 125 most common ISBNs (ranked by distinct sections). Carries institution class (control, iclevel, instsize, sector), the required flag (is_required_inferred = inferred is_required, issue #1), course, faculty, and the full pricing breakdown (buy/rental × new/used × physical/digital) from pricing_wide. Built for cost-difference analysis across institution classes (e.g. public 2-year vs private 4-year). ~183k rows; ~63% have a matched bookstore price (LEFT JOIN — NULL cost = no pricing row); ~75% are required. A handful of exact within-period source dupes (negligible).
WITH top_isbns AS (
    SELECT ISBN13
    FROM comprehensive_data
    WHERE period_sortable = '2025-4' AND ISBN13 IS NOT NULL
    GROUP BY ISBN13
    ORDER BY COUNT(DISTINCT section_id) DESC
    LIMIT 125
)
SELECT
    -- material identity (is_required_inferred = inferred is_required, issue #1)
    c.ISBN13, c.Title AS book_title, c.Author, c.Publisher,
    c.book_status, c.is_required_inferred, c.is_oer, c.is_ia, c.is_supply,
    -- institution (class dimensions for the analysis)
    c.unit_id, c.institution_name, c.state, c.control,
    c.level AS iclevel, c.size AS instsize, c.sector, c.institution_type,
    c.enrollment_2024, c.distance_enrollment_2024,
    -- course
    c.section_id, c.course_id, c.course_title, c.course_subject, c.course_level,
    c.department, c.course_number, c.section, c.period, c.enrollments, c.seats_taken,
    -- faculty
    c.instructor, c.first_name, c.last_name, c.email,
    -- cost: all option × condition × format (purchase = buy, print = physical) from pricing_wide
    pw.bookstore_url,
    pw.price_buy_new_physical,    pw.price_buy_used_physical,
    pw.price_buy_new_digital,     pw.price_buy_used_digital,
    pw.price_buy_new_na,          pw.price_buy_used_na,
    pw.price_buy_na_physical,     pw.price_buy_na_digital,     pw.price_buy_na_na,
    pw.price_rental_new_physical, pw.price_rental_used_physical,
    pw.price_rental_new_digital,  pw.price_rental_used_digital,
    pw.price_rental_new_na,       pw.price_rental_used_na,
    pw.price_rental_na_physical,  pw.price_rental_na_digital,  pw.price_rental_na_na,
    pw.has_buy, pw.has_rent,
    pw.price_min, pw.price_max, pw.price_buy_min, pw.price_buy_max,
    pw.rental_days_min, pw.rental_days_max, pw.format_count
FROM comprehensive_data c
JOIN top_isbns t ON c.ISBN13 = t.ISBN13
LEFT JOIN pricing_wide pw ON c.section_id = pw.section_id AND c.ISBN13 = pw.isbn13
WHERE c.period_sortable = '2025-4'
ORDER BY c.ISBN13, c.control, c.level, c.state, c.section_id
