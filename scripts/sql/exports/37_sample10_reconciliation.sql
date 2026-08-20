-- Full vs deterministic 10% reconciliation (#53).
--
-- Every sampled value is restricted through sample10_section_ids; there is no
-- separate sample pipeline. Additive measures may be multiplied by ten because
-- sections have equal inclusion probability. Distinct institution/ISBN domains
-- are explicitly non-additive: their sample coverage is reported, but 10x is not
-- a valid estimator. Tolerances are deterministic drift alarms, not confidence
-- intervals. The alarm is a two-sided 99.9% normal-reference band (3.2905
-- standard errors). Its Horvitz-Thompson variance is estimated from squared
-- per-section contributions, so whole-section clustering and unequal numbers of
-- materials/enrollments within sections are represented rather than ignored.
WITH sample AS MATERIALIZED (
    SELECT section_id FROM sample10_section_ids
),
catalog AS (
    SELECT
        c.period_sortable,
        COUNT(*) AS catalog_rows_full,
        COUNT(*) FILTER (WHERE sample.section_id IS NOT NULL) AS catalog_rows_sample,
        COUNT(*) FILTER (
            WHERE c."ISBN13" IS NOT NULL
              AND NOT COALESCE(c.is_supply, FALSE)
        ) AS included_material_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL
              AND c."ISBN13" IS NOT NULL
              AND NOT COALESCE(c.is_supply, FALSE)
        ) AS included_material_rows_sample,
        COUNT(*) FILTER (WHERE c."ISBN13" IS NULL) AS blank_isbn_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL AND c."ISBN13" IS NULL
        ) AS blank_isbn_rows_sample,
        COUNT(*) FILTER (WHERE COALESCE(c.is_supply, FALSE)) AS supply_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL AND COALESCE(c.is_supply, FALSE)
        ) AS supply_rows_sample
    FROM comprehensive_data c
    LEFT JOIN sample USING (section_id)
    WHERE c.period_date >= DATE '2024-01-01'
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
    GROUP BY c.period_sortable
),
sampled_catalog_by_section AS MATERIALIZED (
    SELECT
        c.period_sortable,
        c.section_id,
        COUNT(*)::DOUBLE AS catalog_rows,
        COUNT(*) FILTER (
            WHERE c."ISBN13" IS NOT NULL
              AND NOT COALESCE(c.is_supply, FALSE)
        )::DOUBLE AS included_material_rows,
        COUNT(*) FILTER (WHERE c."ISBN13" IS NULL)::DOUBLE AS blank_isbn_rows,
        COUNT(*) FILTER (WHERE COALESCE(c.is_supply, FALSE))::DOUBLE AS supply_rows
    FROM comprehensive_data c
    JOIN sample USING (section_id)
    WHERE c.period_date >= DATE '2024-01-01'
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
    GROUP BY c.period_sortable, c.section_id
),
catalog_squares AS (
    SELECT
        period_sortable,
        SUM(catalog_rows * catalog_rows) AS catalog_rows_sum_squares,
        SUM(included_material_rows * included_material_rows) AS included_material_rows_sum_squares,
        SUM(blank_isbn_rows * blank_isbn_rows) AS blank_isbn_rows_sum_squares,
        SUM(supply_rows * supply_rows) AS supply_rows_sum_squares
    FROM sampled_catalog_by_section
    GROUP BY period_sortable
),
material_spine AS MATERIALIZED (
    SELECT
        c.period_sortable,
        c.section_id,
        c."ISBN13" AS isbn13
    FROM comprehensive_data c
    WHERE c.period_date >= DATE '2024-01-01'
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
      AND c."ISBN13" IS NOT NULL
      AND NOT COALESCE(c.is_supply, FALSE)
    GROUP BY c.period_sortable, c.section_id, c."ISBN13"
),
materials AS (
    SELECT
        spine.period_sortable,
        COUNT(*) AS section_isbn_rows_full,
        COUNT(*) FILTER (WHERE sample.section_id IS NOT NULL) AS section_isbn_rows_sample,
        COUNT(DISTINCT spine.isbn13) AS isbn_rows_full,
        COUNT(DISTINCT spine.isbn13) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS isbn_rows_sample
    FROM material_spine spine
    LEFT JOIN sample USING (section_id)
    GROUP BY spine.period_sortable
),
sampled_material_by_section AS (
    SELECT
        spine.period_sortable,
        spine.section_id,
        COUNT(*)::DOUBLE AS section_isbn_rows
    FROM material_spine spine
    JOIN sample USING (section_id)
    GROUP BY spine.period_sortable, spine.section_id
),
material_squares AS (
    SELECT
        period_sortable,
        SUM(section_isbn_rows * section_isbn_rows) AS section_isbn_rows_sum_squares
    FROM sampled_material_by_section
    GROUP BY period_sortable
),
costs AS (
    SELECT
        sc.period_sortable,
        COUNT(*) AS section_cost_rows_full,
        COUNT(*) FILTER (WHERE sample.section_id IS NOT NULL) AS section_cost_rows_sample,
        SUM(sc.required_priced_count) AS required_priced_materials_full,
        SUM(sc.required_priced_count) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS required_priced_materials_sample,
        SUM(sc.optional_priced_count) AS optional_priced_materials_full,
        SUM(sc.optional_priced_count) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS optional_priced_materials_sample
    FROM section_cost sc
    LEFT JOIN sample USING (section_id)
    GROUP BY sc.period_sortable
),
cost_squares AS (
    SELECT
        sc.period_sortable,
        COUNT(*)::DOUBLE AS section_cost_rows_sum_squares,
        SUM(POWER(COALESCE(sc.required_priced_count, 0)::DOUBLE, 2)) AS required_priced_sum_squares,
        SUM(POWER(COALESCE(sc.optional_priced_count, 0)::DOUBLE, 2)) AS optional_priced_sum_squares
    FROM section_cost sc
    JOIN sample USING (section_id)
    GROUP BY sc.period_sortable
),
sections AS (
    SELECT
        ms.period_sortable,
        COUNT(*) AS section_rows_full,
        COUNT(*) FILTER (WHERE sample.section_id IS NOT NULL) AS section_rows_sample,
        SUM(ms.material_count) AS material_count_full,
        SUM(ms.material_count) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS material_count_sample,
        SUM(ms.enrollment_assigned) AS enrollment_assigned_full,
        SUM(ms.enrollment_assigned) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS enrollment_assigned_sample,
        COUNT(DISTINCT COALESCE(CAST(ms.unit_id AS VARCHAR), '__NULL__')) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS institution_rows_sample
    FROM master_section ms
    LEFT JOIN sample USING (section_id)
    GROUP BY ms.period_sortable
),
section_squares AS (
    SELECT
        ms.period_sortable,
        COUNT(*)::DOUBLE AS section_rows_sum_squares,
        SUM(POWER(ms.material_count::DOUBLE, 2)) AS material_count_sum_squares,
        SUM(POWER(COALESCE(ms.enrollment_assigned, 0)::DOUBLE, 2)) AS enrollment_sum_squares
    FROM master_section ms
    JOIN sample USING (section_id)
    GROUP BY ms.period_sortable
),
institutions AS (
    SELECT period_sortable, COUNT(*) AS institution_rows_full
    FROM master_institution
    GROUP BY period_sortable
),
isbns AS (
    SELECT
        period_sortable,
        COUNT(*) AS isbn_rows_full,
        SUM(section_id_count) AS section_isbn_rows_full
    FROM master_isbn
    GROUP BY period_sortable
),
metrics AS (
    SELECT period_sortable, 'raw_catalog' AS stage, 'catalog_rows' AS metric,
           TRUE AS is_additive, catalog_rows_sum_squares AS sample_sum_squares,
           catalog_rows_full::HUGEINT AS full_value,
           catalog_rows_sample::HUGEINT AS sample_value
    FROM catalog JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'included_materials', 'catalog_rows_with_nonblank_nonsupply_isbn',
           TRUE, included_material_rows_sum_squares, included_material_rows_full::HUGEINT,
           included_material_rows_sample::HUGEINT
    FROM catalog JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'excluded_materials', 'blank_isbn_catalog_rows',
           TRUE, blank_isbn_rows_sum_squares,
           blank_isbn_rows_full::HUGEINT, blank_isbn_rows_sample::HUGEINT
    FROM catalog JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'excluded_materials', 'supply_catalog_rows',
           TRUE, supply_rows_sum_squares,
           supply_rows_full::HUGEINT, supply_rows_sample::HUGEINT
    FROM catalog JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'material_cost_input', 'distinct_section_isbn_rows',
           TRUE, section_isbn_rows_sum_squares,
           section_isbn_rows_full::HUGEINT, section_isbn_rows_sample::HUGEINT
    FROM materials JOIN material_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'section_cost', 'section_rows',
           TRUE, section_cost_rows_sum_squares,
           section_cost_rows_full::HUGEINT, section_cost_rows_sample::HUGEINT
    FROM costs JOIN cost_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'section_cost', 'required_priced_materials',
           TRUE, required_priced_sum_squares, required_priced_materials_full::HUGEINT,
           required_priced_materials_sample::HUGEINT
    FROM costs JOIN cost_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'section_cost', 'optional_priced_materials',
           TRUE, optional_priced_sum_squares, optional_priced_materials_full::HUGEINT,
           optional_priced_materials_sample::HUGEINT
    FROM costs JOIN cost_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'section_rows',
           TRUE, section_rows_sum_squares,
           section_rows_full::HUGEINT, section_rows_sample::HUGEINT
    FROM sections JOIN section_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'material_count',
           TRUE, material_count_sum_squares,
           material_count_full::HUGEINT, material_count_sample::HUGEINT
    FROM sections JOIN section_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'enrollment_assigned_total',
           TRUE, enrollment_sum_squares, enrollment_assigned_full::HUGEINT,
           enrollment_assigned_sample::HUGEINT
    FROM sections JOIN section_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_institution', 'institution_rows',
           FALSE, NULL::DOUBLE, institution_rows_full::HUGEINT,
           institution_rows_sample::HUGEINT
    FROM institutions JOIN sections USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_isbn', 'isbn_rows',
           FALSE, NULL::DOUBLE, isbns.isbn_rows_full::HUGEINT,
           materials.isbn_rows_sample::HUGEINT
    FROM isbns JOIN materials USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_isbn', 'section_isbn_rows',
           TRUE, section_isbn_rows_sum_squares, isbns.section_isbn_rows_full::HUGEINT,
           materials.section_isbn_rows_sample::HUGEINT
    FROM isbns
    JOIN materials USING (period_sortable)
    JOIN material_squares USING (period_sortable)
),
evaluated AS (
    SELECT
        *,
        CASE WHEN is_additive AND full_value > 0 THEN
            SQRT(90.0 * sample_sum_squares)
        END AS scaled_standard_error
    FROM metrics
)
SELECT
    period_sortable,
    stage,
    metric,
    is_additive,
    full_value,
    sample_value,
    ROUND(100.0 * sample_value / NULLIF(full_value, 0), 4) AS sample_pct,
    CASE WHEN is_additive THEN sample_value * 10 END AS scaled_sample_value,
    CASE WHEN is_additive THEN sample_value * 10 - full_value END AS scaled_difference,
    CASE WHEN is_additive THEN
        ROUND(100.0 * (sample_value * 10 - full_value) / NULLIF(full_value, 0), 4)
    END AS scaled_difference_pct,
    ROUND(scaled_standard_error, 4) AS scaled_standard_error,
    CASE WHEN is_additive THEN
        ROUND((sample_value * 10 - full_value) / NULLIF(scaled_standard_error, 0), 4)
    END AS z_score,
    CASE WHEN is_additive THEN
        ROUND(3.2905 * scaled_standard_error / NULLIF(full_value, 0) * 100.0, 4)
    END AS tolerance_pct,
    CASE WHEN is_additive THEN
        ABS(sample_value * 10 - full_value) <= 3.2905 * scaled_standard_error
    END AS within_tolerance,
    CASE WHEN is_additive
         THEN '10x estimates an additive section-cluster total'
         ELSE 'domain coverage only; do not multiply by 10'
    END AS interpretation
FROM evaluated
ORDER BY period_sortable, stage, metric;
