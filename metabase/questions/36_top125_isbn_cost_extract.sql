-- name: Top-125 ISBN Cost Extract — Fall 2025 (institution × course × faculty)
-- display: table
-- description: One row per canonical Use Fall-2025 (period 2025-4) section-adoption of the 125 most common ISBNs (ranked by distinct sections), read from material_costs at its canonical (period_sortable, section_id, isbn13) grain. Carries the deterministic catalog metadata, institution class (control, iclevel, instsize, sector), course, faculty, and the full pricing breakdown (buy/rental × new/used × physical/digital). Built for cost-difference analysis across institution classes (e.g. public 2-year vs private 4-year). Current result expectation: 178,058 adoptions; 112,968 (63.44%) have a matched price and 132,775 (74.57%) are inferred-required. Cost columns remain NULL when the material has no pricing match.
WITH top_isbns AS (
    SELECT isbn13
    FROM material_costs
    WHERE period_sortable = '2025-4'
    GROUP BY isbn13
    ORDER BY COUNT(DISTINCT section_id) DESC
    LIMIT 125
)
SELECT
    -- material identity (is_required_inferred = inferred is_required, issue #1)
    c.isbn13 AS "ISBN13", c.book_title, c.author AS "Author", c.publisher AS "Publisher",
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
    -- cost: all option × condition × format (purchase = buy, print = physical)
    c.bookstore_url,
    c.price_buy_new_physical,    c.price_buy_used_physical,
    c.price_buy_new_digital,     c.price_buy_used_digital,
    c.price_buy_new_na,          c.price_buy_used_na,
    c.price_buy_na_physical,     c.price_buy_na_digital,     c.price_buy_na_na,
    c.price_rental_new_physical, c.price_rental_used_physical,
    c.price_rental_new_digital,  c.price_rental_used_digital,
    c.price_rental_new_na,       c.price_rental_used_na,
    c.price_rental_na_physical,  c.price_rental_na_digital,  c.price_rental_na_na,
    c.has_buy, c.has_rent,
    c.price_min, c.price_max, c.price_buy_min, c.price_buy_max,
    c.rental_days_min, c.rental_days_max, c.format_count
FROM material_costs c
JOIN top_isbns t ON c.isbn13 = t.isbn13
WHERE c.period_sortable = '2025-4'
ORDER BY c.isbn13, c.control, c.level, c.state, c.section_id
