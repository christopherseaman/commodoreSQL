-- Exact current-state reconciliation across the canonical CMM release models (#59).
--
-- Unlike the probabilistic full-vs-10% checks in export 37, every row here must
-- match exactly. material_costs is the approved canonical-Use material input;
-- its distinct section keys are the exact Master Section population, and its item
-- rows sum exactly to Master Section material_count. Master Section contains the
-- section-level cost aggregates from the same input. Master ISBN and Master Institution then reconcile
-- to the narrowed canonical release rollups. Raw full-population diagnostics live
-- in export 37 and the build-time DQ, not in these release equality checks.
-- Bare SELECT by export convention.
WITH material_spine AS MATERIALIZED (
    SELECT period_sortable, section_id, isbn13
    FROM material_costs
),
materials AS (
    SELECT
        spine.period_sortable,
        COUNT(*) AS item_rows,
        COUNT(DISTINCT spine.section_id) AS section_rows,
        SUM(ms.enrollment_assigned) AS enrollment_assigned_total,
        COUNT(*) FILTER (WHERE ms.section_id IS NULL) AS missing_master_section_rows
    FROM material_spine spine
    LEFT JOIN master_section ms
      ON ms.period_sortable = spine.period_sortable
     AND ms.section_id = spine.section_id
    GROUP BY spine.period_sortable
),
cost_by_section AS MATERIALIZED (
    SELECT
        period_sortable,
        section_id,
        COUNT(*) FILTER (WHERE is_required_inferred AND price_min IS NOT NULL) AS required_priced_count,
        COUNT(*) FILTER (WHERE NOT is_required_inferred AND price_min IS NOT NULL) AS optional_priced_count,
        SUM(price_min) FILTER (WHERE is_required_inferred) AS required_cost_total_min,
        SUM(price_max) FILTER (WHERE is_required_inferred) AS required_cost_total_max,
        SUM(price_min) FILTER (WHERE NOT is_required_inferred) AS optional_cost_total_min,
        SUM(price_max) FILTER (WHERE NOT is_required_inferred) AS optional_cost_total_max,
        SUM(price_buy_min) FILTER (WHERE is_required_inferred) AS required_cost_owned_min,
        SUM(price_buy_max) FILTER (WHERE is_required_inferred) AS required_cost_owned_max,
        SUM(price_buy_min) FILTER (WHERE NOT is_required_inferred) AS optional_cost_owned_min,
        SUM(price_buy_max) FILTER (WHERE NOT is_required_inferred) AS optional_cost_owned_max
    FROM material_costs
    GROUP BY period_sortable, section_id
),
costs AS (
    SELECT
        period_sortable,
        COUNT(*) AS use_bearing_sections,
        SUM(required_priced_count) AS required_priced_materials,
        SUM(optional_priced_count) AS optional_priced_materials,
        SUM(required_cost_total_min) AS required_cost_total_min,
        SUM(required_cost_total_max) AS required_cost_total_max,
        SUM(optional_cost_total_min) AS optional_cost_total_min,
        SUM(optional_cost_total_max) AS optional_cost_total_max,
        SUM(required_cost_owned_min) AS required_cost_owned_min,
        SUM(required_cost_owned_max) AS required_cost_owned_max,
        SUM(optional_cost_owned_min) AS optional_cost_owned_min,
        SUM(optional_cost_owned_max) AS optional_cost_owned_max
    FROM cost_by_section
    GROUP BY period_sortable
),
sections AS (
    SELECT
        period_sortable,
        COUNT(*) AS section_rows,
        SUM(material_count) AS item_rows,
        SUM(enrollment_assigned) AS enrollment_assigned_total,
        SUM(required_priced_count) AS required_priced_materials,
        SUM(optional_priced_count) AS optional_priced_materials,
        SUM(required_cost_total_min) AS required_cost_total_min,
        SUM(required_cost_total_max) AS required_cost_total_max,
        SUM(optional_cost_total_min) AS optional_cost_total_min,
        SUM(optional_cost_total_max) AS optional_cost_total_max,
        SUM(required_cost_owned_min) AS required_cost_owned_min,
        SUM(required_cost_owned_max) AS required_cost_owned_max,
        SUM(optional_cost_owned_min) AS optional_cost_owned_min,
        SUM(optional_cost_owned_max) AS optional_cost_owned_max
    FROM master_section
    GROUP BY period_sortable
),
institutions AS (
    SELECT
        period_sortable,
        SUM(section_count) AS section_rows,
        SUM(enrollments_tot) AS enrollment_assigned_total
    FROM master_institution
    GROUP BY period_sortable
),
isbns AS (
    SELECT
        period_sortable,
        SUM(section_id_count) AS section_isbn_rows,
        SUM(enroll_tot) AS enrollment_assigned_total
    FROM master_isbn
    GROUP BY period_sortable
),
terms AS (
    SELECT period_sortable FROM materials
    UNION SELECT period_sortable FROM sections
    UNION SELECT period_sortable FROM costs
    UNION SELECT period_sortable FROM institutions
    UNION SELECT period_sortable FROM isbns
),
reconciled AS (
    SELECT
        t.period_sortable,
        COALESCE(m.section_rows, 0) AS source_material_section_rows,
        COALESCE(m.item_rows, 0) AS source_material_item_rows,
        COALESCE(m.enrollment_assigned_total, 0) AS source_isbn_enrollment_total,
        COALESCE(m.missing_master_section_rows, 0) AS material_rows_missing_master_section,
        COALESCE(cost.use_bearing_sections, 0) AS cost_use_bearing_sections,
        COALESCE(cost.required_priced_materials, 0) AS cost_required_priced_materials,
        COALESCE(cost.optional_priced_materials, 0) AS cost_optional_priced_materials,
        COALESCE(cost.required_cost_total_min, 0) AS cost_required_cost_total_min,
        COALESCE(cost.required_cost_total_max, 0) AS cost_required_cost_total_max,
        COALESCE(cost.optional_cost_total_min, 0) AS cost_optional_cost_total_min,
        COALESCE(cost.optional_cost_total_max, 0) AS cost_optional_cost_total_max,
        COALESCE(cost.required_cost_owned_min, 0) AS cost_required_cost_owned_min,
        COALESCE(cost.required_cost_owned_max, 0) AS cost_required_cost_owned_max,
        COALESCE(cost.optional_cost_owned_min, 0) AS cost_optional_cost_owned_min,
        COALESCE(cost.optional_cost_owned_max, 0) AS cost_optional_cost_owned_max,
        COALESCE(s.section_rows, 0) AS master_section_rows,
        COALESCE(s.item_rows, 0) AS master_section_item_rows,
        COALESCE(s.enrollment_assigned_total, 0) AS master_section_enrollment_total,
        COALESCE(s.required_priced_materials, 0) AS master_section_required_priced_materials,
        COALESCE(s.optional_priced_materials, 0) AS master_section_optional_priced_materials,
        COALESCE(s.required_cost_total_min, 0) AS master_section_required_cost_total_min,
        COALESCE(s.required_cost_total_max, 0) AS master_section_required_cost_total_max,
        COALESCE(s.optional_cost_total_min, 0) AS master_section_optional_cost_total_min,
        COALESCE(s.optional_cost_total_max, 0) AS master_section_optional_cost_total_max,
        COALESCE(s.required_cost_owned_min, 0) AS master_section_required_cost_owned_min,
        COALESCE(s.required_cost_owned_max, 0) AS master_section_required_cost_owned_max,
        COALESCE(s.optional_cost_owned_min, 0) AS master_section_optional_cost_owned_min,
        COALESCE(s.optional_cost_owned_max, 0) AS master_section_optional_cost_owned_max,
        COALESCE(i.section_rows, 0) AS master_institution_section_rows,
        COALESCE(i.enrollment_assigned_total, 0) AS master_institution_enrollment_total,
        COALESCE(mi.section_isbn_rows, 0) AS master_isbn_section_isbn_rows,
        COALESCE(mi.enrollment_assigned_total, 0) AS master_isbn_enrollment_total
    FROM terms t
    LEFT JOIN materials m USING (period_sortable)
    LEFT JOIN costs cost USING (period_sortable)
    LEFT JOIN sections s USING (period_sortable)
    LEFT JOIN institutions i USING (period_sortable)
    LEFT JOIN isbns mi USING (period_sortable)
),
metrics AS (
    SELECT period_sortable, 'key_integrity' AS stage, 'material_rows_missing_master_section' AS metric,
           0 AS source_value, material_rows_missing_master_section AS release_value
    FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section', 'section_rows',
           source_material_section_rows AS source_value, master_section_rows AS release_value
    FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section', 'item_rows',
           source_material_item_rows, master_section_item_rows FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'use_bearing_sections',
           cost_use_bearing_sections, master_section_rows FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'required_priced_materials',
           cost_required_priced_materials, master_section_required_priced_materials FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'optional_priced_materials',
           cost_optional_priced_materials, master_section_optional_priced_materials FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'required_cost_total_min',
           cost_required_cost_total_min, master_section_required_cost_total_min FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'required_cost_total_max',
           cost_required_cost_total_max, master_section_required_cost_total_max FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'optional_cost_total_min',
           cost_optional_cost_total_min, master_section_optional_cost_total_min FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'optional_cost_total_max',
           cost_optional_cost_total_max, master_section_optional_cost_total_max FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'required_cost_owned_min',
           cost_required_cost_owned_min, master_section_required_cost_owned_min FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'required_cost_owned_max',
           cost_required_cost_owned_max, master_section_required_cost_owned_max FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'optional_cost_owned_min',
           cost_optional_cost_owned_min, master_section_optional_cost_owned_min FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_section_costs', 'optional_cost_owned_max',
           cost_optional_cost_owned_max, master_section_optional_cost_owned_max FROM reconciled
    UNION ALL SELECT period_sortable, 'master_section_to_master_institution', 'section_rows',
           master_section_rows, master_institution_section_rows FROM reconciled
    UNION ALL SELECT period_sortable, 'master_section_to_master_institution', 'enrollment_assigned_total',
           master_section_enrollment_total, master_institution_enrollment_total FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_isbn', 'section_isbn_rows',
           source_material_item_rows, master_isbn_section_isbn_rows FROM reconciled
    UNION ALL SELECT period_sortable, 'material_costs_to_master_isbn', 'enrollment_assigned_total',
           source_isbn_enrollment_total, master_isbn_enrollment_total FROM reconciled
)
SELECT
    period_sortable,
    stage,
    metric,
    source_value,
    release_value,
    release_value - source_value AS difference,
    release_value = source_value AS is_match
FROM metrics
ORDER BY period_sortable, stage, metric;
