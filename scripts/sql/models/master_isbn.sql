-- Canonical Master ISBN model query (issue #55).
--
-- Grain: exactly one row per (period_sortable, isbn13), for 2024+ catalog
-- rows in the canonical issue-#58 Use population. The Fall-2025
-- row set is therefore period_sortable = '2025-4'; no term literal is baked in.
--
-- The section_isbn spine is distinct before any joins.  pricing_wide is already
-- one row per (section_id, isbn13), so joining it here avoids both the raw
-- pricing rental-term multiplicity and multiplying catalog listing duplicates.
-- Enrollment is the persisted master_section.enrollment_assigned value (the
-- existing own/seats/sibling/median hierarchy), never raw enrollment totals.

WITH raw_materials AS (
    SELECT
        c.period_sortable,
        c."ISBN13" AS isbn13,
        c.section_id,
        c.course_id,
        c.unit_id,
        NULLIF(TRIM(c."Title"), '') AS title,
        NULLIF(TRIM(c."Author"), '') AS author,
        NULLIF(TRIM(c."Publisher"), '') AS publisher,
        COALESCE(c.is_oer, FALSE) AS is_oer,
        COALESCE(c.is_ia, FALSE) AS is_ia,
        COALESCE(c.is_supply, FALSE) AS is_supply
    FROM comprehensive_data c
    WHERE c.period_date >= DATE '2024-01-01'
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
      AND c.is_course_material_use
),
-- One catalog material instance per section/ISBN.  All section-level counts
-- below are derived from this spine, not from repeated catalog listings.
section_isbn AS MATERIALIZED (
    SELECT
        period_sortable, isbn13, section_id,
        ANY_VALUE(course_id) AS course_id,
        ANY_VALUE(unit_id) AS unit_id
    FROM raw_materials
    GROUP BY period_sortable, isbn13, section_id
),
metadata AS (
    SELECT
        period_sortable, isbn13,
        -- MIN over trimmed nonblank values is deterministic and stable across
        -- thread counts; variant counts expose where a source conflict exists.
        MIN(title) AS book_title,
        MIN(author) AS author,
        MIN(publisher) AS publisher,
        COUNT(DISTINCT title) AS title_variant_count,
        COUNT(DISTINCT author) AS author_variant_count,
        COUNT(DISTINCT publisher) AS publisher_variant_count
    FROM raw_materials
    GROUP BY period_sortable, isbn13
),
flags AS (
    SELECT period_sortable, isbn13,
           COALESCE(BOOL_OR(is_oer), FALSE) AS is_oer,
           COALESCE(BOOL_OR(is_ia), FALSE) AS is_ia
    FROM raw_materials
    GROUP BY period_sortable, isbn13
),
material_rows AS MATERIALIZED (
    SELECT
        si.*,
        ms.enrollment_assigned,
        ms.institution_type,
        p.price_buy_new_physical, p.price_buy_new_digital, p.price_buy_new_na,
        p.price_buy_used_physical, p.price_buy_used_digital, p.price_buy_used_na,
        p.price_buy_na_physical, p.price_buy_na_digital, p.price_buy_na_na,
        p.price_rental_new_physical, p.price_rental_new_digital, p.price_rental_new_na,
        p.price_rental_used_physical, p.price_rental_used_digital, p.price_rental_used_na,
        p.price_rental_na_physical, p.price_rental_na_digital, p.price_rental_na_na
    FROM section_isbn si
    LEFT JOIN master_section ms ON ms.section_id = si.section_id
    LEFT JOIN pricing_wide p
      ON p.section_id = si.section_id AND p.isbn13 = si.isbn13
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
        -- Definitive flags follow the project convention: BOOL_OR across the
        -- material's catalog rows. Supply is false by the WHERE filter above.
        ANY_VALUE(f.is_oer) AS is_oer,
        ANY_VALUE(f.is_ia) AS is_ia,
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
    FROM material_rows m
    JOIN flags f USING (period_sortable, isbn13)
    GROUP BY period_sortable, isbn13
)
SELECT
    a.period_sortable,
    a.isbn13,
    md.book_title,
    md.author,
    md.publisher,
    a.is_oer,
    a.is_ia,
    a.is_supply,
    a.unit_id_count,
    a.section_id_count,
    a.course_id_count,
    a.has_enrollment,
    a.enroll_cnt,
    a.enroll_tot,
    md.title_variant_count,
    md.author_variant_count,
    md.publisher_variant_count,
    (md.title_variant_count > 1 OR md.author_variant_count > 1 OR md.publisher_variant_count > 1) AS metadata_conflict,
    a.* EXCLUDE (period_sortable, isbn13, is_oer, is_ia, is_supply, unit_id_count, section_id_count,
                course_id_count, has_enrollment, enroll_cnt, enroll_tot)
FROM aggregated a
LEFT JOIN metadata md USING (period_sortable, isbn13)
ORDER BY a.period_sortable, a.isbn13;
