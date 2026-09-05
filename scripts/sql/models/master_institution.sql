-- Canonical Master Institution model query (#54).
--
-- Grain: one row per (period_sortable, unit_id) represented by material-bearing
-- master_section. The export intentionally includes the NULL unit_id bucket: those
-- retained section rows have no institution key with which to resolve a URL.
-- run_sql.sh materializes this bare SELECT as table master_institution.
--
-- Source decisions (the supplied workbook and processing notes disagree in places):
-- * Every rollup count is over material-bearing Master Section rows. Enrollment
--   fields are inherited through master_material; direct required context and the
--   comprehensive-data supply audit cover excluded
--   rows co-occurring with retained sections. Keeping direct required separate from
--   inferred required preserves the source contract and exposes the inference rule.
-- * required_priced_section_count and optional_priced_section_count follow the actual
--   required/optional status. The source labels Req_priced_count/Opt_priced_count
--   describe the opposite status in their prose; status-aligned names avoid that trap.
-- * assigned enrollment is authoritative for enrollment_section_count and its total;
--   raw enrollments is not re-imputed here. seats_taken=9999 is the documented invalid
--   sentinel, so it is excluded from seat counts and totals.
-- * bookstore_url is an institution-metadata exception to the canonical material
--   flow. It is selected from all same-term pricing rows so institutions do not
--   lose a known URL merely because those priced items fall outside canonical Use.
--   The URL occurring on the most pricing rows wins; lexical ordering is the
--   deterministic tie-break. URLs are not inferred for NULL unit_id.
WITH section_flags AS (
    SELECT
        ms.*,
        (ms.material_count > 0) AS has_material,
        (ms.required_count > 0) AS is_required_inferred,
        (ms.optional_count > 0) AS is_optional,
        (ms.supply_count > 0) AS has_supply,
        (ms.oer_count > 0) AS has_oer,
        (ms.ia_count > 0) AS has_ia,
        (ms.required_priced_count > 0) AS is_required_priced,
        (ms.optional_priced_count > 0) AS is_optional_priced,
        (ms.isbn_count > 0) AS has_isbn,
        (ms.enrollment_assigned IS NOT NULL) AS has_assigned_enrollment,
        (ms.seats_taken IS NOT NULL AND ms.seats_taken < 9999) AS has_valid_seats
    FROM master_section ms
    WHERE ms.period_sortable IS NOT NULL
),
url_counts AS (
    SELECT
        REGEXP_EXTRACT(pricing.section_id, '::([0-9]{4}-[1-4])$', 1) AS period_sortable,
        pricing.unit_id,
        pricing.bookstore_url,
        COUNT(*) AS pricing_rows
    FROM pricing_wide pricing
    WHERE pricing.unit_id IS NOT NULL
      AND pricing.bookstore_url IS NOT NULL
      AND pricing.bookstore_url <> ''
    GROUP BY 1, 2, 3
),
ranked_urls AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY period_sortable, unit_id
            ORDER BY pricing_rows DESC, bookstore_url ASC
        ) AS url_rank
    FROM url_counts
),
institution_rollup AS (
    SELECT
        period_sortable,
        unit_id,
        -- Institution fields are unit-grain in the upstream IPEDS enrichment.
        ANY_VALUE(state) AS state,
        ANY_VALUE(control) AS control,
        ANY_VALUE(level) AS level,
        ANY_VALUE(size) AS size,
        ANY_VALUE(institution_name) AS institution_name,
        ANY_VALUE(institution_type) AS institution_type,
        ANY_VALUE(enrollment_2024) AS enrollment_2024,
        ANY_VALUE(distance_enrollment_2024) AS distance_enrollment_2024,
        COUNT(*) AS section_count,
        COUNT(*) FILTER (WHERE course_level = 'Advanced graduate') AS advanced_graduate_section_count,
        COUNT(*) FILTER (WHERE course_level = 'Advanced graduate/ directed study and research') AS advanced_graduate_directed_study_and_research_section_count,
        COUNT(*) FILTER (WHERE course_level = 'Advanced undergraduate') AS advanced_undergraduate_section_count,
        COUNT(*) FILTER (WHERE course_level = 'Advanced undergraduate/ graduate') AS advanced_undergraduate_graduate_section_count,
        COUNT(*) FILTER (WHERE course_level = 'General graduate') AS general_graduate_section_count,
        COUNT(*) FILTER (WHERE course_level = 'Intermediate undergraduate') AS intermediate_undergraduate_section_count,
        COUNT(*) FILTER (WHERE course_level = 'Introductory or general undergraduate') AS introductory_or_general_undergraduate_section_count,
        COUNT(*) FILTER (WHERE course_level = 'Non-degree credit') AS non_degree_credit_section_count,
        COUNT(*) FILTER (WHERE course_level = 'Uncategorized') AS uncategorized_section_count,
        COUNT(DISTINCT course_id) AS course_count,
        COUNT(*) FILTER (WHERE has_material) AS material_section_count,
        COUNT(*) FILTER (WHERE is_required_direct) AS required_section_count,
        COUNT(*) FILTER (WHERE is_required_inferred) AS inferred_required_section_count,
        COUNT(*) FILTER (WHERE is_optional) AS optional_section_count,
        COUNT(*) FILTER (WHERE has_supply) AS supply_section_count,
        COUNT(*) FILTER (WHERE has_oer) AS oer_section_count,
        COUNT(*) FILTER (WHERE has_ia) AS ia_section_count,
        COUNT(*) FILTER (WHERE is_required_priced) AS required_priced_section_count,
        COUNT(*) FILTER (WHERE is_optional_priced) AS optional_priced_section_count,
        COUNT(*) FILTER (WHERE has_isbn) AS isbn_section_count,
        COUNT(*) FILTER (WHERE has_assigned_enrollment) AS enrollment_section_count,
        COUNT(*) FILTER (WHERE has_valid_seats) AS seats_taken_section_count,
        SUM(enrollment_assigned) AS enrollments_tot,
        SUM(seats_taken) FILTER (WHERE has_valid_seats) AS seats_taken_tot
    FROM section_flags
    GROUP BY period_sortable, unit_id
)
SELECT
    ir.period_sortable,
    ir.unit_id,
    ir.state,
    ir.control,
    ir.level,
    ir.size,
    ir.institution_name,
    ir.institution_type,
    ir.enrollment_2024,
    ir.distance_enrollment_2024,
    ru.bookstore_url,
    ir.section_count,
    ir.advanced_graduate_section_count,
    ir.advanced_graduate_directed_study_and_research_section_count,
    ir.advanced_undergraduate_section_count,
    ir.advanced_undergraduate_graduate_section_count,
    ir.general_graduate_section_count,
    ir.intermediate_undergraduate_section_count,
    ir.introductory_or_general_undergraduate_section_count,
    ir.non_degree_credit_section_count,
    ir.uncategorized_section_count,
    ir.course_count,
    ir.material_section_count,
    ir.required_section_count,
    ir.inferred_required_section_count,
    ir.optional_section_count,
    ir.supply_section_count,
    ir.oer_section_count,
    ir.ia_section_count,
    ir.required_priced_section_count,
    ir.optional_priced_section_count,
    ir.isbn_section_count,
    ir.enrollment_section_count,
    ir.seats_taken_section_count,
    ir.enrollments_tot,
    ir.seats_taken_tot
FROM institution_rollup ir
LEFT JOIN ranked_urls ru
  ON ru.period_sortable = ir.period_sortable
 AND ru.unit_id = ir.unit_id
 AND ru.url_rank = 1;
