-- Exact current-state reconciliation across the canonical CMM release models (#59).
--
-- Unlike the probabilistic full-vs-10% checks in export 37, every row here must
-- match exactly. master_material is the approved canonical-Use material input;
-- its distinct section keys are the exact Master Section population, and its item
-- rows sum exactly to Master Section material_count. Master Section contains the
-- section-level cost aggregates from the same input. Master ISBN and Master Institution then reconcile
-- to the narrowed canonical release rollups. Raw full-population diagnostics live
-- in export 37 and the build-time DQ, not in these release equality checks.
-- Bare SELECT by export convention.
WITH material_spine AS MATERIALIZED (
    SELECT period_sortable, section_id, isbn13
    FROM master_material
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
        SUM(price_min) FILTER (WHERE is_required_inferred) AS required_price_min,
        SUM(price_max) FILTER (WHERE is_required_inferred) AS required_price_max,
        SUM(price_buy_min) FILTER (WHERE is_required_inferred) AS required_price_buy_min,
        SUM(price_buy_max) FILTER (WHERE is_required_inferred) AS required_price_buy_max,
        SUM(price_min) AS all_price_min,
        SUM(price_max) AS all_price_max,
        SUM(price_buy_min) AS all_price_buy_min,
        SUM(price_buy_max) AS all_price_buy_max
    FROM master_material
    GROUP BY period_sortable, section_id
),
costs AS (
    SELECT
        period_sortable,
        COUNT(*) AS use_bearing_sections,
        SUM(required_priced_count) AS required_priced_materials,
        SUM(optional_priced_count) AS optional_priced_materials,
        SUM(required_price_min) AS required_price_min,
        SUM(required_price_max) AS required_price_max,
        SUM(required_price_buy_min) AS required_price_buy_min,
        SUM(required_price_buy_max) AS required_price_buy_max,
        SUM(all_price_min) AS all_price_min,
        SUM(all_price_max) AS all_price_max,
        SUM(all_price_buy_min) AS all_price_buy_min,
        SUM(all_price_buy_max) AS all_price_buy_max
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
        SUM(required_price_min) AS required_price_min,
        SUM(required_price_max) AS required_price_max,
        SUM(required_price_buy_min) AS required_price_buy_min,
        SUM(required_price_buy_max) AS required_price_buy_max,
        SUM(all_price_min) AS all_price_min,
        SUM(all_price_max) AS all_price_max,
        SUM(all_price_buy_min) AS all_price_buy_min,
        SUM(all_price_buy_max) AS all_price_buy_max
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
        COALESCE(cost.required_price_min, 0) AS cost_required_price_min,
        COALESCE(cost.required_price_max, 0) AS cost_required_price_max,
        COALESCE(cost.required_price_buy_min, 0) AS cost_required_price_buy_min,
        COALESCE(cost.required_price_buy_max, 0) AS cost_required_price_buy_max,
        COALESCE(cost.all_price_min, 0) AS cost_all_price_min,
        COALESCE(cost.all_price_max, 0) AS cost_all_price_max,
        COALESCE(cost.all_price_buy_min, 0) AS cost_all_price_buy_min,
        COALESCE(cost.all_price_buy_max, 0) AS cost_all_price_buy_max,
        COALESCE(s.section_rows, 0) AS master_section_rows,
        COALESCE(s.item_rows, 0) AS master_section_item_rows,
        COALESCE(s.enrollment_assigned_total, 0) AS master_section_enrollment_total,
        COALESCE(s.required_priced_materials, 0) AS master_section_required_priced_materials,
        COALESCE(s.optional_priced_materials, 0) AS master_section_optional_priced_materials,
        COALESCE(s.required_price_min, 0) AS master_section_required_price_min,
        COALESCE(s.required_price_max, 0) AS master_section_required_price_max,
        COALESCE(s.required_price_buy_min, 0) AS master_section_required_price_buy_min,
        COALESCE(s.required_price_buy_max, 0) AS master_section_required_price_buy_max,
        COALESCE(s.all_price_min, 0) AS master_section_all_price_min,
        COALESCE(s.all_price_max, 0) AS master_section_all_price_max,
        COALESCE(s.all_price_buy_min, 0) AS master_section_all_price_buy_min,
        COALESCE(s.all_price_buy_max, 0) AS master_section_all_price_buy_max,
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
    UNION ALL SELECT period_sortable, 'master_material_to_master_section', 'section_rows',
           source_material_section_rows AS source_value, master_section_rows AS release_value
    FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section', 'item_rows',
           source_material_item_rows, master_section_item_rows FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_cost', 'use_bearing_sections',
           cost_use_bearing_sections, master_section_rows FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_cost', 'required_priced_materials',
           cost_required_priced_materials, master_section_required_priced_materials FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_cost', 'optional_priced_materials',
           cost_optional_priced_materials, master_section_optional_priced_materials FROM reconciled
    UNION ALL SELECT period_sortable, 'price_midpoint_invariant', 'master_section',
           0, COUNT(*) FILTER (
               WHERE required_price_avg IS DISTINCT FROM
                     (required_price_min + required_price_max) / 2.0
                  OR all_price_avg IS DISTINCT FROM
                     (all_price_min + all_price_max) / 2.0
           )
    FROM master_section GROUP BY period_sortable
    UNION ALL SELECT period_sortable, 'price_midpoint_invariant', 'master_course',
           0, COUNT(*) FILTER (
               WHERE required_price_avg IS DISTINCT FROM
                     (required_price_min + required_price_max) / 2.0
                  OR all_price_avg IS DISTINCT FROM
                     (all_price_min + all_price_max) / 2.0
           )
    FROM master_course GROUP BY period_sortable
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_price', 'required_price_min',
           cost_required_price_min, master_section_required_price_min FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_price', 'required_price_max',
           cost_required_price_max, master_section_required_price_max FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_price', 'required_price_buy_min',
           cost_required_price_buy_min, master_section_required_price_buy_min FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_price', 'required_price_buy_max',
           cost_required_price_buy_max, master_section_required_price_buy_max FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_price', 'all_price_min',
           cost_all_price_min, master_section_all_price_min FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_price', 'all_price_max',
           cost_all_price_max, master_section_all_price_max FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_price', 'all_price_buy_min',
           cost_all_price_buy_min, master_section_all_price_buy_min FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_section_price', 'all_price_buy_max',
           cost_all_price_buy_max, master_section_all_price_buy_max FROM reconciled
    UNION ALL SELECT period_sortable, 'master_section_to_master_institution', 'section_rows',
           master_section_rows, master_institution_section_rows FROM reconciled
    UNION ALL SELECT period_sortable, 'master_section_to_master_institution', 'enrollment_assigned_total',
           master_section_enrollment_total, master_institution_enrollment_total FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_isbn', 'section_isbn_rows',
           source_material_item_rows, master_isbn_section_isbn_rows FROM reconciled
    UNION ALL SELECT period_sortable, 'master_material_to_master_isbn', 'enrollment_assigned_total',
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
