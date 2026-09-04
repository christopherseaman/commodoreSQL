-- name: Coverage & Scope — Canonical Retained Sections by Institution Profile
-- display: table
-- description: Institution-profile rollups; percentages divide by retained canonical sections. Complete institution-profile coverage summary from canonical master_institution at one row per period_sortable × state × control × level × size × institution_type. institution_count counts source institution rows (including the explicit NULL-institution bucket), and bookstore_url_institution_count counts rows with a nonblank bookstore URL. All section, course, material, source-required, inferred-required, inferred-optional, priced, supply, OER, IA, and enrollment metrics are summed across the profile. canonical_retained_section_count is the summed canonical retained-section denominator for every pct_* column; it is not the complete section_enrollment spine. source_required_section_count is the source-required count from section_book_status, while inferred-required and inferred-optional counts are the catalog-inferred split.

SELECT
    period_sortable,
    state,
    control,
    level,
    size,
    institution_type,
    COUNT(*) AS institution_count,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(bookstore_url), '') IS NOT NULL)
        AS bookstore_url_institution_count,
    SUM(section_count) AS canonical_retained_section_count,
    SUM(course_count) AS course_count,
    SUM(material_section_count) AS material_section_count,
    SUM(required_section_count) AS source_required_section_count,
    SUM(inferred_required_section_count) AS inferred_required_section_count,
    SUM(optional_section_count) AS inferred_optional_section_count,
    SUM(required_priced_section_count) AS inferred_required_priced_section_count,
    SUM(optional_priced_section_count) AS inferred_optional_priced_section_count,
    SUM(supply_section_count) AS supply_section_count,
    SUM(oer_section_count) AS oer_section_count,
    SUM(ia_section_count) AS ia_section_count,
    SUM(enrollment_section_count) AS enrollment_section_count,
    ROUND(100.0 * SUM(material_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_material_of_canonical_retained_sections,
    ROUND(100.0 * SUM(required_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_source_required_of_canonical_retained_sections,
    ROUND(100.0 * SUM(inferred_required_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_inferred_required_of_canonical_retained_sections,
    ROUND(100.0 * SUM(optional_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_inferred_optional_of_canonical_retained_sections,
    ROUND(100.0 * SUM(required_priced_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_inferred_required_priced_of_canonical_retained_sections,
    ROUND(100.0 * SUM(optional_priced_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_inferred_optional_priced_of_canonical_retained_sections,
    ROUND(100.0 * SUM(supply_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_supply_sidecar_of_canonical_retained_sections,
    ROUND(100.0 * SUM(oer_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_oer_of_canonical_retained_sections,
    ROUND(100.0 * SUM(ia_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_ia_of_canonical_retained_sections,
    ROUND(100.0 * SUM(enrollment_section_count) / NULLIF(SUM(section_count), 0), 2)
        AS pct_assigned_enrollment_of_canonical_retained_sections
FROM master_institution
WHERE 1 = 1
[[ AND {{period_sortable}} ]]
GROUP BY period_sortable, state, control, level, size, institution_type
ORDER BY period_sortable, state, control, level, size, institution_type
