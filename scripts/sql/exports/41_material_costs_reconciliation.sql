-- Exact raw -> canonical Course Materials -> Material Costs reconciliation (#65).
-- Pricing-match interpretation and alternative join designs are documented once,
-- in the CMM-ETL.md issue #21 limitation. Bare SELECT by export convention.
WITH canonical_use_keys AS MATERIALIZED (
    SELECT
        period_sortable,
        section_id,
        isbn13,
        TRUE AS canonical_present
    FROM course_materials_use
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
        COALESCE(canonical.period_sortable, material.period_sortable) AS period_sortable,
        canonical.canonical_present IS NOT NULL AS canonical_present,
        material.row_count IS NOT NULL AS material_present
    FROM canonical_use_keys canonical
    FULL OUTER JOIN material_key_groups material
      ON material.period_sortable = canonical.period_sortable
     AND material.section_id = canonical.section_id
     AND material.isbn13 = canonical.isbn13
),
raw_metrics AS MATERIALIZED (
    SELECT
        period_sortable,
        COUNT(*) AS raw_valid_post_2024_rows,
        COUNT(DISTINCT (section_id, "ISBN13")) AS raw_distinct_item_keys,
        COUNT(*) FILTER (WHERE "ISBN13" IS NULL) AS raw_null_isbn_rows,
        COUNT(DISTINCT section_id) FILTER (WHERE "ISBN13" IS NULL)
            AS raw_null_isbn_sections,
        COUNT(*) FILTER (WHERE is_course_material_use) AS raw_use_rows,
        COUNT(DISTINCT (section_id, "ISBN13"))
            FILTER (WHERE is_course_material_use) AS raw_distinct_use_keys
    FROM comprehensive_data
    WHERE is_post_2024
      AND period_sortable IS NOT NULL
      AND section_id IS NOT NULL
    GROUP BY period_sortable
),
canonical_metrics AS MATERIALIZED (
    SELECT
        period_sortable,
        COUNT(*) AS canonical_course_material_rows,
        COUNT(*) - COUNT(DISTINCT (section_id, isbn13))
            AS canonical_course_material_duplicate_key_rows,
        SUM(source_row_count) AS canonical_represented_raw_rows,
        COUNT(*) FILTER (WHERE is_null_isbn_audit)
            AS canonical_null_isbn_audit_rows,
        SUM(source_row_count) FILTER (WHERE is_null_isbn_audit)
            AS canonical_null_isbn_source_rows,
        COUNT(*) FILTER (WHERE is_course_material_use) AS canonical_use_rows,
        SUM(use_source_row_count) FILTER (WHERE is_course_material_use)
            AS canonical_use_source_rows
    FROM course_materials
    WHERE is_post_2024
    GROUP BY period_sortable
),
terms AS (
    -- Include NoUse-only terms as well as terms reaching Material Costs; otherwise
    -- a whole raw/canonical population could disappear from this reconciliation.
    SELECT period_sortable FROM raw_metrics
    UNION
    SELECT period_sortable FROM canonical_metrics
    UNION
    SELECT period_sortable FROM canonical_use_keys
    UNION
    SELECT period_sortable FROM material_costs WHERE period_sortable IS NOT NULL
),
material_metrics AS MATERIALIZED (
    SELECT
        period_sortable,
        COUNT(*) AS material_cost_rows,
        COUNT(*) FILTER (WHERE has_pricing_match) AS pricing_match_rows,
        COUNT(*) FILTER (WHERE NOT has_pricing_match) AS pricing_unmatched_rows,
        COUNT(*) FILTER (WHERE has_pricing_match AND price_min IS NULL)
            AS matched_without_valid_price_rows,
        COUNT(*) FILTER (WHERE price_min IS NULL) AS null_price_min_rows,
        COUNT(*) FILTER (WHERE has_pricing_match IS NULL)
            AS null_pricing_match_flag_rows,
        COUNT(*) FILTER (
            WHERE period_sortable IS NULL OR section_id IS NULL OR isbn13 IS NULL
        ) AS null_key_rows
    FROM material_costs
    GROUP BY period_sortable
),
uniqueness_metrics AS (
    SELECT
        period_sortable,
        SUM(row_count - 1) AS material_cost_duplicate_key_rows
    FROM material_key_groups
    GROUP BY period_sortable
),
key_metrics AS (
    SELECT
        period_sortable,
        COUNT(*) FILTER (WHERE canonical_present AND NOT material_present)
            AS missing_from_material_costs,
        COUNT(*) FILTER (WHERE NOT canonical_present AND material_present)
            AS extra_in_material_costs
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
        COALESCE(raw.raw_valid_post_2024_rows, 0) AS raw_valid_post_2024_rows,
        COALESCE(raw.raw_distinct_item_keys, 0) AS raw_distinct_item_keys,
        COALESCE(raw.raw_valid_post_2024_rows - raw.raw_distinct_item_keys, 0)
            AS raw_rows_collapsed,
        COALESCE(raw.raw_null_isbn_rows, 0) AS raw_null_isbn_rows,
        COALESCE(raw.raw_null_isbn_sections, 0) AS raw_null_isbn_sections,
        COALESCE(raw.raw_use_rows, 0) AS raw_use_rows,
        COALESCE(raw.raw_distinct_use_keys, 0) AS raw_distinct_use_keys,
        COALESCE(canonical.canonical_course_material_rows, 0)
            AS canonical_course_material_rows,
        COALESCE(canonical.canonical_course_material_duplicate_key_rows, 0)
            AS canonical_course_material_duplicate_key_rows,
        COALESCE(canonical.canonical_represented_raw_rows, 0)
            AS canonical_represented_raw_rows,
        COALESCE(canonical.canonical_null_isbn_audit_rows, 0)
            AS canonical_null_isbn_audit_rows,
        COALESCE(canonical.canonical_null_isbn_source_rows, 0)
            AS canonical_null_isbn_source_rows,
        COALESCE(canonical.canonical_use_rows, 0) AS canonical_use_rows,
        COALESCE(canonical.canonical_use_source_rows, 0) AS canonical_use_source_rows,
        COALESCE(material.material_cost_rows, 0) AS material_cost_rows,
        COALESCE(unique_keys.material_cost_duplicate_key_rows, 0)
            AS material_cost_duplicate_key_rows,
        COALESCE(material.null_key_rows, 0) AS null_key_rows,
        COALESCE(material.pricing_match_rows, 0) AS pricing_match_rows,
        COALESCE(material.pricing_unmatched_rows, 0) AS pricing_unmatched_rows,
        COALESCE(material.matched_without_valid_price_rows, 0)
            AS matched_without_valid_price_rows,
        COALESCE(material.null_price_min_rows, 0) AS null_price_min_rows,
        COALESCE(material.null_pricing_match_flag_rows, 0)
            AS null_pricing_match_flag_rows,
        COALESCE(keys.missing_from_material_costs, 0) AS missing_from_material_costs,
        COALESCE(keys.extra_in_material_costs, 0) AS extra_in_material_costs,
        COALESCE(coverage.rows_missing_master_section, 0) AS rows_missing_master_section
    FROM terms
    LEFT JOIN raw_metrics raw USING (period_sortable)
    LEFT JOIN canonical_metrics canonical USING (period_sortable)
    LEFT JOIN material_metrics material USING (period_sortable)
    LEFT JOIN uniqueness_metrics unique_keys USING (period_sortable)
    LEFT JOIN key_metrics keys USING (period_sortable)
    LEFT JOIN coverage_metrics coverage USING (period_sortable)
),
reported AS (
    SELECT * FROM per_term
    UNION ALL BY NAME
    SELECT
        '__ALL__' AS period_sortable,
        SUM(raw_valid_post_2024_rows) AS raw_valid_post_2024_rows,
        SUM(raw_distinct_item_keys) AS raw_distinct_item_keys,
        SUM(raw_rows_collapsed) AS raw_rows_collapsed,
        SUM(raw_null_isbn_rows) AS raw_null_isbn_rows,
        SUM(raw_null_isbn_sections) AS raw_null_isbn_sections,
        SUM(raw_use_rows) AS raw_use_rows,
        SUM(raw_distinct_use_keys) AS raw_distinct_use_keys,
        SUM(canonical_course_material_rows) AS canonical_course_material_rows,
        SUM(canonical_course_material_duplicate_key_rows)
            AS canonical_course_material_duplicate_key_rows,
        SUM(canonical_represented_raw_rows) AS canonical_represented_raw_rows,
        SUM(canonical_null_isbn_audit_rows) AS canonical_null_isbn_audit_rows,
        SUM(canonical_null_isbn_source_rows) AS canonical_null_isbn_source_rows,
        SUM(canonical_use_rows) AS canonical_use_rows,
        SUM(canonical_use_source_rows) AS canonical_use_source_rows,
        SUM(material_cost_rows) AS material_cost_rows,
        SUM(material_cost_duplicate_key_rows) AS material_cost_duplicate_key_rows,
        SUM(null_key_rows) AS null_key_rows,
        SUM(pricing_match_rows) AS pricing_match_rows,
        SUM(pricing_unmatched_rows) AS pricing_unmatched_rows,
        SUM(matched_without_valid_price_rows) AS matched_without_valid_price_rows,
        SUM(null_price_min_rows) AS null_price_min_rows,
        SUM(null_pricing_match_flag_rows) AS null_pricing_match_flag_rows,
        SUM(missing_from_material_costs) AS missing_from_material_costs,
        SUM(extra_in_material_costs) AS extra_in_material_costs,
        SUM(rows_missing_master_section) AS rows_missing_master_section
    FROM per_term
)
SELECT
    *,
    COALESCE(
      raw_valid_post_2024_rows = canonical_represented_raw_rows
      AND raw_distinct_item_keys = canonical_course_material_rows
      AND raw_null_isbn_rows = canonical_null_isbn_source_rows
      AND raw_null_isbn_sections = canonical_null_isbn_audit_rows
      AND raw_use_rows = canonical_use_source_rows
      AND raw_distinct_use_keys = canonical_use_rows
      AND canonical_course_material_duplicate_key_rows = 0
      AND canonical_use_rows = material_cost_rows
      AND material_cost_duplicate_key_rows = 0
      AND null_key_rows = 0
      AND null_pricing_match_flag_rows = 0
      AND pricing_match_rows + pricing_unmatched_rows = material_cost_rows
      AND null_price_min_rows = pricing_unmatched_rows + matched_without_valid_price_rows
      AND missing_from_material_costs = 0
      AND extra_in_material_costs = 0
      AND rows_missing_master_section = 0,
      FALSE
    ) AS is_match
FROM reported
ORDER BY period_sortable = '__ALL__', period_sortable;
