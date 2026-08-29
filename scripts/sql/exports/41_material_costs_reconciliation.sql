-- Exact reconciliation for the canonical Material Costs release model.
--
-- Current exact-match evidence and alternatives are centralized in the CMM-ETL.md
-- issue #21 limitation. This query keeps the evidence dynamic: every current term
-- must have identical source/material key sets, unique non-NULL material keys, and
-- complete Master Section coverage. Bare SELECT by export convention.
WITH source_keys AS MATERIALIZED (
    SELECT
        period_sortable,
        section_id,
        "ISBN13" AS isbn13,
        TRUE AS source_present
    FROM comprehensive_data
    WHERE period_date >= DATE '2024-01-01'
      AND period_sortable IS NOT NULL
      AND section_id IS NOT NULL
      AND is_course_material_use
    GROUP BY period_sortable, section_id, "ISBN13"
),
material_key_groups AS MATERIALIZED (
    SELECT
        period_sortable,
        section_id,
        isbn13,
        COUNT(*) AS row_count
    FROM material_costs
    GROUP BY period_sortable, section_id, isbn13
),
key_presence AS MATERIALIZED (
    SELECT
        COALESCE(source.period_sortable, material.period_sortable) AS period_sortable,
        source.source_present IS NOT NULL AS source_present,
        material.row_count IS NOT NULL AS material_present
    FROM source_keys source
    FULL OUTER JOIN material_key_groups material
      ON material.period_sortable = source.period_sortable
     AND material.section_id = source.section_id
     AND material.isbn13 = source.isbn13
),
terms AS (
    SELECT period_sortable FROM source_keys
    UNION
    SELECT period_sortable FROM material_costs WHERE period_sortable IS NOT NULL
),
source_metrics AS (
    SELECT period_sortable, COUNT(*) AS source_distinct_use_keys
    FROM source_keys
    GROUP BY period_sortable
),
material_metrics AS (
    SELECT
        period_sortable,
        COUNT(*) AS material_cost_rows,
        COUNT(*) FILTER (WHERE has_pricing_match) AS pricing_match_rows,
        COUNT(*) FILTER (WHERE NOT has_pricing_match) AS pricing_unmatched_rows,
        COUNT(*) FILTER (WHERE has_pricing_match AND price_min IS NULL)
            AS matched_without_valid_price_rows,
        COUNT(*) FILTER (WHERE price_min IS NULL) AS null_price_min_rows,
        COUNT(*) FILTER (WHERE has_pricing_match IS NULL) AS null_pricing_match_flag_rows,
        COUNT(*) FILTER (
            WHERE period_sortable IS NULL OR section_id IS NULL OR isbn13 IS NULL
        ) AS null_key_rows
    FROM material_costs
    GROUP BY period_sortable
),
uniqueness_metrics AS (
    SELECT
        period_sortable,
        SUM(row_count - 1) AS duplicate_key_rows
    FROM material_key_groups
    GROUP BY period_sortable
),
key_metrics AS (
    SELECT
        period_sortable,
        COUNT(*) FILTER (WHERE source_present AND NOT material_present) AS missing_from_material_costs,
        COUNT(*) FILTER (WHERE NOT source_present AND material_present) AS extra_in_material_costs
    FROM key_presence
    GROUP BY period_sortable
),
coverage_metrics AS (
    SELECT
        mc.period_sortable,
        COUNT(*) FILTER (WHERE ms.section_id IS NULL) AS rows_missing_master_section
    FROM material_costs mc
    LEFT JOIN master_section ms
      ON ms.period_sortable = mc.period_sortable
     AND ms.section_id = mc.section_id
    GROUP BY mc.period_sortable
),
per_term AS (
    SELECT
        terms.period_sortable,
        COALESCE(source.source_distinct_use_keys, 0) AS source_distinct_use_keys,
        COALESCE(material.material_cost_rows, 0) AS material_cost_rows,
        COALESCE(unique_keys.duplicate_key_rows, 0) AS duplicate_key_rows,
        COALESCE(material.null_key_rows, 0) AS null_key_rows,
        COALESCE(material.pricing_match_rows, 0) AS pricing_match_rows,
        COALESCE(material.pricing_unmatched_rows, 0) AS pricing_unmatched_rows,
        COALESCE(material.matched_without_valid_price_rows, 0)
            AS matched_without_valid_price_rows,
        COALESCE(material.null_price_min_rows, 0) AS null_price_min_rows,
        COALESCE(material.null_pricing_match_flag_rows, 0) AS null_pricing_match_flag_rows,
        COALESCE(keys.missing_from_material_costs, 0) AS missing_from_material_costs,
        COALESCE(keys.extra_in_material_costs, 0) AS extra_in_material_costs,
        COALESCE(coverage.rows_missing_master_section, 0) AS rows_missing_master_section
    FROM terms
    LEFT JOIN source_metrics source USING (period_sortable)
    LEFT JOIN material_metrics material USING (period_sortable)
    LEFT JOIN uniqueness_metrics unique_keys USING (period_sortable)
    LEFT JOIN key_metrics keys USING (period_sortable)
    LEFT JOIN coverage_metrics coverage USING (period_sortable)
),
reported AS (
    SELECT * FROM per_term
    UNION ALL
    SELECT
        '__ALL__' AS period_sortable,
        COUNT(*) AS source_distinct_use_keys,
        (SELECT COUNT(*) FROM material_costs) AS material_cost_rows,
        (SELECT COALESCE(SUM(row_count - 1), 0) FROM material_key_groups) AS duplicate_key_rows,
        (SELECT COUNT(*) FROM material_costs
          WHERE period_sortable IS NULL OR section_id IS NULL OR isbn13 IS NULL) AS null_key_rows,
        (SELECT COUNT(*) FROM material_costs WHERE has_pricing_match) AS pricing_match_rows,
        (SELECT COUNT(*) FROM material_costs WHERE NOT has_pricing_match) AS pricing_unmatched_rows,
        (SELECT COUNT(*) FROM material_costs
          WHERE has_pricing_match AND price_min IS NULL) AS matched_without_valid_price_rows,
        (SELECT COUNT(*) FROM material_costs WHERE price_min IS NULL) AS null_price_min_rows,
        (SELECT COUNT(*) FROM material_costs WHERE has_pricing_match IS NULL) AS null_pricing_match_flag_rows,
        (SELECT COUNT(*) FROM key_presence
          WHERE source_present AND NOT material_present) AS missing_from_material_costs,
        (SELECT COUNT(*) FROM key_presence
          WHERE NOT source_present AND material_present) AS extra_in_material_costs,
        (SELECT COUNT(*)
         FROM material_costs mc
         LEFT JOIN master_section ms
           ON ms.period_sortable = mc.period_sortable
          AND ms.section_id = mc.section_id
         WHERE ms.section_id IS NULL) AS rows_missing_master_section
    FROM source_keys
)
SELECT
    *,
    source_distinct_use_keys = material_cost_rows
      AND duplicate_key_rows = 0
      AND null_key_rows = 0
      AND null_pricing_match_flag_rows = 0
      AND pricing_match_rows + pricing_unmatched_rows = material_cost_rows
      AND null_price_min_rows = pricing_unmatched_rows + matched_without_valid_price_rows
      AND missing_from_material_costs = 0
      AND extra_in_material_costs = 0
      AND rows_missing_master_section = 0 AS is_match
FROM reported
ORDER BY period_sortable = '__ALL__', period_sortable;
