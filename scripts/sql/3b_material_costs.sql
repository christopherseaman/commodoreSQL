-- Pricing enrichment of canonical Course Materials Use items.
--
-- course_materials owns item identity, catalog metadata, population flags,
-- duplicate/conflict evidence, and enrollment assignment. pricing_wide remains
-- source-owned and contributes only bookstore/pricing fields through a LEFT join.

${CONFIG}

DROP TABLE IF EXISTS material_costs;
CREATE TABLE material_costs AS
SELECT
    -- Preserve the established Material Costs prefix through has_pricing_match.
    -- The renamed direct-status fields occupy the two former literal-status slots;
    -- new section context and existing audits follow the legacy prefix.
    cm.* EXCLUDE (
        panel_source_row_count,
        panel_response_year_variant_count,
        is_section_required_direct,
        use_source_row_count,
        no_use_source_row_count,
        has_use_source_row,
        has_no_use_source_row,
        population_classification_conflict,
        instructor_variant_count,
        email_variant_count,
        contact_metadata_conflict,
        is_supply_conflict,
        no_details_conflict,
        no_materials_conflict,
        is_canada_conflict,
        is_null_isbn_audit,
        has_nonnull_isbn_in_section,
        is_no_adoption_section
    ),
    pw.bookstore_url,
    pw.price_buy_new_physical,
    pw.price_buy_new_digital,
    pw.price_buy_new_na,
    pw.price_buy_used_physical,
    pw.price_buy_used_digital,
    pw.price_buy_used_na,
    pw.price_buy_na_physical,
    pw.price_buy_na_digital,
    pw.price_buy_na_na,
    pw.price_rental_new_physical,
    pw.price_rental_new_digital,
    pw.price_rental_new_na,
    pw.price_rental_used_physical,
    pw.price_rental_used_digital,
    pw.price_rental_used_na,
    pw.price_rental_na_physical,
    pw.price_rental_na_digital,
    pw.price_rental_na_na,
    pw.format_count,
    pw.has_buy,
    pw.has_rent,
    pw.price_min,
    pw.price_max,
    pw.price_avg,
    pw.rental_days_min,
    pw.rental_days_max,
    pw.price_buy_min,
    pw.price_buy_max,
    (pw.section_id IS NOT NULL) AS has_pricing_match,
    cm.is_section_required_direct,
    cm.panel_source_row_count,
    cm.panel_response_year_variant_count,
    cm.use_source_row_count,
    cm.no_use_source_row_count,
    cm.has_use_source_row,
    cm.has_no_use_source_row,
    cm.population_classification_conflict,
    cm.instructor_variant_count,
    cm.email_variant_count,
    cm.contact_metadata_conflict,
    cm.is_supply_conflict,
    cm.no_details_conflict,
    cm.no_materials_conflict,
    cm.is_canada_conflict,
    cm.is_null_isbn_audit,
    cm.has_nonnull_isbn_in_section,
    cm.is_no_adoption_section
FROM course_materials_use cm
LEFT JOIN pricing_wide pw
  ON cm.section_id = pw.section_id
 AND CAST(cm.isbn13 AS VARCHAR) = pw.isbn13;

SELECT
    'material_costs grain/key/price DQ' AS metric,
    COUNT(*) AS rows,
    COUNT(*) - COUNT(DISTINCT (period_sortable, section_id, isbn13)) AS duplicate_rows,
    COUNT(*) FILTER (
        WHERE period_sortable IS NULL OR section_id IS NULL OR isbn13 IS NULL
    ) AS key_null_rows,
    COUNT(*) FILTER (WHERE has_pricing_match) AS pricing_match_rows,
    COUNT(*) FILTER (WHERE has_pricing_match AND price_min IS NOT NULL) AS priced_rows,
    COUNT(*) FILTER (WHERE NOT has_pricing_match) AS no_pricing_match_rows
FROM material_costs;

WITH course_material_keys AS (
    SELECT period_sortable, section_id, isbn13
    FROM course_materials_use
), material_keys AS (
    SELECT period_sortable, section_id, isbn13
    FROM material_costs
), key_presence AS (
    SELECT
        course_material.period_sortable AS course_material_period,
        material.period_sortable AS material_period
    FROM course_material_keys course_material
    FULL OUTER JOIN material_keys material
      ON course_material.period_sortable = material.period_sortable
     AND course_material.section_id = material.section_id
     AND course_material.isbn13 = material.isbn13
)
SELECT
    'Course Materials Use to material_costs key conservation' AS metric,
    (SELECT COUNT(*) FROM course_material_keys) AS course_material_use_rows,
    (SELECT COUNT(*) FROM material_keys) AS material_cost_rows,
    COUNT(*) FILTER (WHERE course_material_period IS NOT NULL AND material_period IS NULL)
        AS missing_from_material_costs,
    COUNT(*) FILTER (WHERE course_material_period IS NULL AND material_period IS NOT NULL)
        AS extra_in_material_costs
FROM key_presence;

SELECT
    'material_costs duplicate/conflict DQ' AS metric,
    COUNT(*) FILTER (WHERE source_row_count > 1) AS duplicate_source_keys,
    COUNT(*) FILTER (WHERE catalog_metadata_conflict) AS metadata_conflict_keys,
    COUNT(*) FILTER (WHERE contact_metadata_conflict) AS contact_conflict_keys,
    COUNT(*) FILTER (WHERE population_classification_conflict)
        AS population_conflict_keys,
    COUNT(*) FILTER (WHERE is_required_inferred_conflict) AS required_conflict_keys,
    COUNT(*) FILTER (WHERE is_oer_conflict) AS oer_conflict_keys,
    COUNT(*) FILTER (WHERE is_ia_conflict) AS ia_conflict_keys,
    COUNT(*) FILTER (WHERE is_supply_conflict) AS supply_conflict_keys,
    COUNT(*) FILTER (WHERE no_details_conflict) AS no_details_conflict_keys,
    COUNT(*) FILTER (WHERE no_materials_conflict) AS no_materials_conflict_keys,
    COUNT(*) FILTER (WHERE is_canada_conflict) AS canada_conflict_keys
FROM material_costs;

ANALYZE material_costs;
