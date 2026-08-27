-- Canonical Master ISBN model query (issue #55).
--
-- Grain: exactly one row per (period_sortable, isbn13), for 2024+ catalog
-- rows in the canonical issue-#58 Use population. The Fall-2025
-- row set is therefore period_sortable = '2025-4'; no term literal is baked in.
--
-- material_costs owns the distinct section/ISBN spine, its 1:1 pricing join, the
-- persisted section enrollment assignment, and the established term/ISBN
-- metadata contract. This rollup does not return to raw catalog or pricing rows.

WITH material_rows AS MATERIALIZED (
    SELECT
        period_sortable,
        isbn13,
        isbn_book_title,
        isbn_author,
        isbn_publisher,
        isbn_title_variant_count,
        isbn_author_variant_count,
        isbn_publisher_variant_count,
        is_oer,
        is_ia,
        section_id,
        course_id,
        unit_id,
        enrollment_assigned,
        institution_type,
        price_buy_new_physical, price_buy_new_digital, price_buy_new_na,
        price_buy_used_physical, price_buy_used_digital, price_buy_used_na,
        price_buy_na_physical, price_buy_na_digital, price_buy_na_na,
        price_rental_new_physical, price_rental_new_digital, price_rental_new_na,
        price_rental_used_physical, price_rental_used_digital, price_rental_used_na,
        price_rental_na_physical, price_rental_na_digital, price_rental_na_na
    FROM material_costs
),
aggregated AS (
    SELECT
        period_sortable,
        isbn13,
        COUNT(DISTINCT unit_id) AS unit_id_count,
        COUNT(DISTINCT section_id) AS section_id_count,
        COUNT(DISTINCT course_id) AS course_id_count,
        COALESCE(BOOL_OR(enrollment_assigned IS NOT NULL), FALSE) AS has_enrollment,
        COUNT(DISTINCT section_id) FILTER (WHERE enrollment_assigned IS NOT NULL) AS enroll_cnt,
        COALESCE(SUM(enrollment_assigned), 0) AS enroll_tot,
        ANY_VALUE(isbn_book_title) AS book_title,
        ANY_VALUE(isbn_author) AS author,
        ANY_VALUE(isbn_publisher) AS publisher,
        ANY_VALUE(isbn_title_variant_count) AS title_variant_count,
        ANY_VALUE(isbn_author_variant_count) AS author_variant_count,
        ANY_VALUE(isbn_publisher_variant_count) AS publisher_variant_count,
        -- Definitive flags follow the project convention: BOOL_OR across the
        -- material's canonical rows. Supply is false in the Use population.
        COALESCE(BOOL_OR(is_oer), FALSE) AS is_oer,
        COALESCE(BOOL_OR(is_ia), FALSE) AS is_ia,
        FALSE AS is_supply,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_new_physical IS NOT NULL) AS price_buy_new_physical_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_new_digital IS NOT NULL) AS price_buy_new_digital_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_new_na IS NOT NULL) AS price_buy_new_na_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_used_physical IS NOT NULL) AS price_buy_used_physical_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_used_digital IS NOT NULL) AS price_buy_used_digital_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_used_na IS NOT NULL) AS price_buy_used_na_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_na_physical IS NOT NULL) AS price_buy_na_physical_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_na_digital IS NOT NULL) AS price_buy_na_digital_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_buy_na_na IS NOT NULL) AS price_buy_na_na_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_new_physical IS NOT NULL) AS price_rental_new_physical_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_new_digital IS NOT NULL) AS price_rental_new_digital_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_new_na IS NOT NULL) AS price_rental_new_na_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_used_physical IS NOT NULL) AS price_rental_used_physical_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_used_digital IS NOT NULL) AS price_rental_used_digital_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_used_na IS NOT NULL) AS price_rental_used_na_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_na_physical IS NOT NULL) AS price_rental_na_physical_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_na_digital IS NOT NULL) AS price_rental_na_digital_count,
        COUNT(DISTINCT section_id) FILTER (WHERE price_rental_na_na IS NOT NULL) AS price_rental_na_na_count,
        COUNT(DISTINCT section_id) FILTER (WHERE institution_type = '2 Year Priavte Profit') AS institution_type_2_year_private_profit_count,
        COUNT(DISTINCT section_id) FILTER (WHERE institution_type = '2 Year Private') AS institution_type_2_year_private_count,
        COUNT(DISTINCT section_id) FILTER (WHERE institution_type = '2 Year Public') AS institution_type_2_year_public_count,
        COUNT(DISTINCT section_id) FILTER (WHERE institution_type = '4 Year Priavte Profit') AS institution_type_4_year_private_profit_count,
        COUNT(DISTINCT section_id) FILTER (WHERE institution_type = '4 Year Private') AS institution_type_4_year_private_count,
        COUNT(DISTINCT section_id) FILTER (WHERE institution_type = '4 Year Public') AS institution_type_4_year_public_count,
        COUNT(DISTINCT section_id) FILTER (WHERE institution_type = 'Under 2 Year Public') AS institution_type_under_2_year_public_count,
        COUNT(DISTINCT section_id) FILTER (WHERE institution_type IS NULL OR institution_type = '') AS institution_type_unknown_count
    FROM material_rows
    GROUP BY period_sortable, isbn13
)
SELECT
    a.period_sortable,
    a.isbn13,
    a.book_title,
    a.author,
    a.publisher,
    a.is_oer,
    a.is_ia,
    a.is_supply,
    a.unit_id_count,
    a.section_id_count,
    a.course_id_count,
    a.has_enrollment,
    a.enroll_cnt,
    a.enroll_tot,
    a.title_variant_count,
    a.author_variant_count,
    a.publisher_variant_count,
    (a.title_variant_count > 1 OR a.author_variant_count > 1 OR a.publisher_variant_count > 1) AS metadata_conflict,
    a.* EXCLUDE (period_sortable, isbn13, book_title, author, publisher,
                title_variant_count, author_variant_count, publisher_variant_count,
                is_oer, is_ia, is_supply, unit_id_count, section_id_count,
                course_id_count, has_enrollment, enroll_cnt, enroll_tot)
FROM aggregated a
ORDER BY a.period_sortable, a.isbn13;
