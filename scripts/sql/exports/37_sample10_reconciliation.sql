-- Full vs deterministic 10% reconciliation (#53).
--
-- Sampled material rows use the same stable section hash as this complete-section
-- diagnostic sample; there is no separate sample pipeline. Additive measures may
-- be multiplied by ten because sections have equal inclusion probability.
-- Distinct institution/ISBN domains
-- are explicitly non-additive: their sample coverage is reported, but 10x is not
-- a valid estimator. Tolerances are deterministic drift alarms, not confidence
-- intervals. The alarm is a two-sided 99.9% normal-reference band (3.2905
-- standard errors). Its Horvitz-Thompson variance is estimated from squared
-- per-section contributions, so whole-section clustering and unequal numbers of
-- materials/enrollments within sections are represented rather than ignored.
-- Raw Use/NoUse, Canada, and placeholder row totals remain full-catalog additive
-- diagnostics even though their exclusion booleans overlap. Canonical material
-- metrics use material_costs. Distinct institution/ISBN domains remain
-- coverage-only. Sample membership itself comes from the complete
-- section_enrollment population.
WITH sample AS MATERIALIZED (
    SELECT
        period_sortable,
        section_id
    FROM section_enrollment
    WHERE CAST('0x' || LEFT(md5(section_id), 16) AS UBIGINT) % 10 = 0
),
catalog AS (
    SELECT
        c.period_sortable,
        COUNT(*) AS catalog_rows_full,
        COUNT(*) FILTER (WHERE sample.section_id IS NOT NULL) AS catalog_rows_sample,
        COUNT(*) FILTER (
            WHERE c.is_course_material_use
        ) AS included_material_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL
              AND c.is_course_material_use
        ) AS included_material_rows_sample,
        COUNT(*) FILTER (WHERE c.is_course_material_no_use) AS no_use_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL AND c.is_course_material_no_use
        ) AS no_use_rows_sample,
        COUNT(*) FILTER (WHERE c.is_canada) AS canada_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL AND c.is_canada
        ) AS canada_rows_sample,
        COUNT(*) FILTER (WHERE c.no_details) AS no_details_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL AND c.no_details
        ) AS no_details_rows_sample,
        COUNT(*) FILTER (WHERE c.no_materials) AS no_materials_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL AND c.no_materials
        ) AS no_materials_rows_sample,
        COUNT(*) FILTER (WHERE c."ISBN13" IS NULL) AS blank_isbn_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL AND c."ISBN13" IS NULL
        ) AS blank_isbn_rows_sample,
        COUNT(*) FILTER (WHERE COALESCE(c.is_supply, FALSE)) AS supply_rows_full,
        COUNT(*) FILTER (
            WHERE sample.section_id IS NOT NULL AND COALESCE(c.is_supply, FALSE)
        ) AS supply_rows_sample
    FROM comprehensive_data c
    LEFT JOIN sample USING (period_sortable, section_id)
    WHERE c.period_date >= DATE '2024-01-01'
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
    GROUP BY c.period_sortable
),
catalog_reason_cardinality AS (
    SELECT
        c.period_sortable,
        CAST(c.is_canada AS INTEGER)
          + CAST(NOT c.has_isbn AS INTEGER)
          + CAST(c.is_supply AS INTEGER)
          + CAST(c.no_details AS INTEGER)
          + CAST(c.no_materials AS INTEGER) AS no_use_reason_count,
        COUNT(*) AS catalog_rows_full,
        COUNT(*) FILTER (WHERE sample.section_id IS NOT NULL) AS catalog_rows_sample
    FROM comprehensive_data c
    LEFT JOIN sample USING (period_sortable, section_id)
    WHERE c.is_post_2024
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
    GROUP BY c.period_sortable, no_use_reason_count
),
sampled_catalog_by_section AS MATERIALIZED (
    SELECT
        c.period_sortable,
        c.section_id,
        COUNT(*)::DOUBLE AS catalog_rows,
        COUNT(*) FILTER (
            WHERE c.is_course_material_use
        )::DOUBLE AS included_material_rows,
        COUNT(*) FILTER (WHERE c.is_course_material_no_use)::DOUBLE AS no_use_rows,
        COUNT(*) FILTER (WHERE c.is_canada)::DOUBLE AS canada_rows,
        COUNT(*) FILTER (WHERE c.no_details)::DOUBLE AS no_details_rows,
        COUNT(*) FILTER (WHERE c.no_materials)::DOUBLE AS no_materials_rows,
        COUNT(*) FILTER (WHERE c."ISBN13" IS NULL)::DOUBLE AS blank_isbn_rows,
        COUNT(*) FILTER (WHERE COALESCE(c.is_supply, FALSE))::DOUBLE AS supply_rows
    FROM comprehensive_data c
    JOIN sample USING (period_sortable, section_id)
    WHERE c.period_date >= DATE '2024-01-01'
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
    GROUP BY c.period_sortable, c.section_id
),
sampled_reason_cardinality_by_section AS (
    SELECT
        c.period_sortable,
        c.section_id,
        CAST(c.is_canada AS INTEGER)
          + CAST(NOT c.has_isbn AS INTEGER)
          + CAST(c.is_supply AS INTEGER)
          + CAST(c.no_details AS INTEGER)
          + CAST(c.no_materials AS INTEGER) AS no_use_reason_count,
        COUNT(*)::DOUBLE AS catalog_rows
    FROM comprehensive_data c
    JOIN sample USING (period_sortable, section_id)
    WHERE c.is_post_2024
      AND c.period_sortable IS NOT NULL
      AND c.section_id IS NOT NULL
    GROUP BY c.period_sortable, c.section_id, no_use_reason_count
),
catalog_squares AS (
    SELECT
        period_sortable,
        SUM(catalog_rows * catalog_rows) AS catalog_rows_sum_squares,
        SUM(included_material_rows * included_material_rows) AS included_material_rows_sum_squares,
        SUM(no_use_rows * no_use_rows) AS no_use_rows_sum_squares,
        SUM(canada_rows * canada_rows) AS canada_rows_sum_squares,
        SUM(no_details_rows * no_details_rows) AS no_details_rows_sum_squares,
        SUM(no_materials_rows * no_materials_rows) AS no_materials_rows_sum_squares,
        SUM(blank_isbn_rows * blank_isbn_rows) AS blank_isbn_rows_sum_squares,
        SUM(supply_rows * supply_rows) AS supply_rows_sum_squares
    FROM sampled_catalog_by_section
    GROUP BY period_sortable
),
reason_cardinality_squares AS (
    SELECT
        period_sortable,
        no_use_reason_count,
        SUM(catalog_rows * catalog_rows) AS catalog_rows_sum_squares
    FROM sampled_reason_cardinality_by_section
    GROUP BY period_sortable, no_use_reason_count
),
material_spine AS MATERIALIZED (
    SELECT
        period_sortable,
        section_id,
        isbn13
    FROM material_costs
),
sampled_material_spine AS MATERIALIZED (
    SELECT
        period_sortable,
        section_id,
        isbn13
    FROM sample10pct_materials
),
material_full AS (
    SELECT
        spine.period_sortable,
        COUNT(*) AS section_isbn_rows_full,
        COUNT(DISTINCT spine.isbn13) AS isbn_rows_full
    FROM material_spine spine
    GROUP BY spine.period_sortable
),
material_sample AS (
    SELECT
        period_sortable,
        COUNT(*) AS section_isbn_rows_sample,
        COUNT(DISTINCT isbn13) AS isbn_rows_sample
    FROM sampled_material_spine
    GROUP BY period_sortable
),
materials AS (
    SELECT
        f.period_sortable,
        f.section_isbn_rows_full,
        s.section_isbn_rows_sample,
        f.isbn_rows_full,
        s.isbn_rows_sample
    FROM material_full f
    LEFT JOIN material_sample s USING (period_sortable)
),
sampled_material_by_section AS (
    SELECT
        spine.period_sortable,
        spine.section_id,
        COUNT(*)::DOUBLE AS section_isbn_rows
    FROM sampled_material_spine spine
    GROUP BY spine.period_sortable, spine.section_id
),
material_squares AS (
    SELECT
        period_sortable,
        SUM(section_isbn_rows * section_isbn_rows) AS section_isbn_rows_sum_squares
    FROM sampled_material_by_section
    GROUP BY period_sortable
),
pricing_counts AS (
    SELECT
        ms.period_sortable,
        COUNT(*) AS priced_section_rows_full,
        COUNT(*) FILTER (WHERE sample.section_id IS NOT NULL) AS priced_section_rows_sample,
        SUM(ms.required_priced_count) AS required_priced_materials_full,
        SUM(ms.required_priced_count) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS required_priced_materials_sample,
        SUM(ms.optional_priced_count) AS optional_priced_materials_full,
        SUM(ms.optional_priced_count) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS optional_priced_materials_sample
    FROM master_section ms
    LEFT JOIN sample USING (period_sortable, section_id)
    GROUP BY ms.period_sortable
),
pricing_count_squares AS (
    SELECT
        ms.period_sortable,
        COUNT(*)::DOUBLE AS priced_section_rows_sum_squares,
        SUM(POWER(COALESCE(ms.required_priced_count, 0)::DOUBLE, 2)) AS required_priced_sum_squares,
        SUM(POWER(COALESCE(ms.optional_priced_count, 0)::DOUBLE, 2)) AS optional_priced_sum_squares
    FROM master_section ms
    JOIN sample USING (period_sortable, section_id)
    GROUP BY ms.period_sortable
),
section_population AS (
    SELECT
        enrollment.period_sortable,
        COUNT(*) AS section_rows_full,
        COUNT(*) FILTER (WHERE sample.section_id IS NOT NULL) AS section_rows_sample,
        SUM(enrollment.enrollment_assigned) AS enrollment_assigned_full,
        SUM(enrollment.enrollment_assigned) FILTER (
            WHERE sample.section_id IS NOT NULL
        ) AS enrollment_assigned_sample
    FROM section_enrollment enrollment
    LEFT JOIN sample USING (period_sortable, section_id)
    GROUP BY enrollment.period_sortable
),
section_population_squares AS (
    SELECT
        enrollment.period_sortable,
        COUNT(*)::DOUBLE AS section_rows_sum_squares,
        SUM(POWER(COALESCE(enrollment.enrollment_assigned, 0)::DOUBLE, 2))
            AS enrollment_sum_squares
    FROM section_enrollment enrollment
    JOIN sample USING (period_sortable, section_id)
    GROUP BY enrollment.period_sortable
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
    LEFT JOIN sample USING (period_sortable, section_id)
    GROUP BY ms.period_sortable
),
section_squares AS (
    SELECT
        ms.period_sortable,
        COUNT(*)::DOUBLE AS section_rows_sum_squares,
        SUM(POWER(ms.material_count::DOUBLE, 2)) AS material_count_sum_squares,
        SUM(POWER(COALESCE(ms.enrollment_assigned, 0)::DOUBLE, 2)) AS enrollment_sum_squares
    FROM master_section ms
    JOIN sample USING (period_sortable, section_id)
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
    FROM catalog LEFT JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'population', 'course_material_use_catalog_rows',
           TRUE, included_material_rows_sum_squares, included_material_rows_full::HUGEINT,
           included_material_rows_sample::HUGEINT
    FROM catalog LEFT JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'population', 'course_material_no_use_catalog_rows',
           TRUE, no_use_rows_sum_squares, no_use_rows_full::HUGEINT,
           no_use_rows_sample::HUGEINT
    FROM catalog LEFT JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'population', 'canada_catalog_rows',
           TRUE, canada_rows_sum_squares, canada_rows_full::HUGEINT,
           canada_rows_sample::HUGEINT
    FROM catalog LEFT JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'population', 'no_details_catalog_rows',
           TRUE, no_details_rows_sum_squares, no_details_rows_full::HUGEINT,
           no_details_rows_sample::HUGEINT
    FROM catalog LEFT JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'population', 'no_materials_catalog_rows',
           TRUE, no_materials_rows_sum_squares, no_materials_rows_full::HUGEINT,
           no_materials_rows_sample::HUGEINT
    FROM catalog LEFT JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT
        crc.period_sortable,
        'population_overlap',
        'no_use_reason_count_' || CAST(crc.no_use_reason_count AS VARCHAR) || '_catalog_rows',
        TRUE,
        rcs.catalog_rows_sum_squares,
        crc.catalog_rows_full::HUGEINT,
        crc.catalog_rows_sample::HUGEINT
    FROM catalog_reason_cardinality crc
    LEFT JOIN reason_cardinality_squares rcs
      USING (period_sortable, no_use_reason_count)
    UNION ALL
    SELECT period_sortable, 'excluded_materials', 'blank_isbn_catalog_rows',
           TRUE, blank_isbn_rows_sum_squares,
           blank_isbn_rows_full::HUGEINT, blank_isbn_rows_sample::HUGEINT
    FROM catalog LEFT JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'excluded_materials', 'supply_catalog_rows',
           TRUE, supply_rows_sum_squares,
           supply_rows_full::HUGEINT, supply_rows_sample::HUGEINT
    FROM catalog LEFT JOIN catalog_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'material_cost_input', 'distinct_section_isbn_rows',
           TRUE, section_isbn_rows_sum_squares,
           section_isbn_rows_full::HUGEINT, COALESCE(section_isbn_rows_sample, 0)::HUGEINT
    FROM materials LEFT JOIN material_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'priced_section_rows',
           TRUE, priced_section_rows_sum_squares,
           priced_section_rows_full::HUGEINT, COALESCE(priced_section_rows_sample, 0)::HUGEINT
    FROM pricing_counts LEFT JOIN pricing_count_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'required_priced_materials',
           TRUE, required_priced_sum_squares, required_priced_materials_full::HUGEINT,
           COALESCE(required_priced_materials_sample, 0)::HUGEINT
    FROM pricing_counts LEFT JOIN pricing_count_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'optional_priced_materials',
           TRUE, optional_priced_sum_squares, optional_priced_materials_full::HUGEINT,
           COALESCE(optional_priced_materials_sample, 0)::HUGEINT
    FROM pricing_counts LEFT JOIN pricing_count_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'section_enrollment', 'section_rows',
           TRUE, section_rows_sum_squares,
           section_rows_full::HUGEINT, COALESCE(section_rows_sample, 0)::HUGEINT
    FROM section_population LEFT JOIN section_population_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'section_enrollment', 'enrollment_assigned_total',
           TRUE, enrollment_sum_squares,
           enrollment_assigned_full::HUGEINT, COALESCE(enrollment_assigned_sample, 0)::HUGEINT
    FROM section_population LEFT JOIN section_population_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'section_rows',
           TRUE, section_rows_sum_squares,
           section_rows_full::HUGEINT, COALESCE(section_rows_sample, 0)::HUGEINT
    FROM sections LEFT JOIN section_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'material_count',
           TRUE, material_count_sum_squares,
           material_count_full::HUGEINT, COALESCE(material_count_sample, 0)::HUGEINT
    FROM sections LEFT JOIN section_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_section', 'enrollment_assigned_total',
           TRUE, enrollment_sum_squares, enrollment_assigned_full::HUGEINT,
           COALESCE(enrollment_assigned_sample, 0)::HUGEINT
    FROM sections LEFT JOIN section_squares USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_institution', 'institution_rows',
           FALSE, NULL::DOUBLE, institution_rows_full::HUGEINT,
           institution_rows_sample::HUGEINT
    FROM institutions JOIN sections USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_isbn', 'isbn_rows',
           FALSE, NULL::DOUBLE, isbns.isbn_rows_full::HUGEINT,
           COALESCE(materials.isbn_rows_sample, 0)::HUGEINT
    FROM isbns JOIN materials USING (period_sortable)
    UNION ALL
    SELECT period_sortable, 'master_isbn', 'section_isbn_rows',
           TRUE, section_isbn_rows_sum_squares, isbns.section_isbn_rows_full::HUGEINT,
           COALESCE(materials.section_isbn_rows_sample, 0)::HUGEINT
    FROM isbns
    JOIN materials USING (period_sortable)
    LEFT JOIN material_squares USING (period_sortable)
),
evaluated AS (
    SELECT
        *,
        CASE
          WHEN is_additive
           AND full_value > 0
           AND COALESCE(sample_sum_squares, 0) > 0
          THEN
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
    CASE
      WHEN is_additive
       AND NOT (full_value > 0 AND COALESCE(sample_sum_squares, 0) = 0)
      THEN
        ABS(sample_value * 10 - full_value) <= 3.2905 * scaled_standard_error
    END AS within_tolerance,
    CASE
        WHEN is_additive
         AND full_value > 0
         AND COALESCE(sample_sum_squares, 0) = 0
        THEN 'sparse category absent from sample; tolerance is not testable'
        WHEN is_additive
        THEN '10x estimates an additive section-cluster total'
        ELSE 'domain coverage only; do not multiply by 10'
    END AS interpretation
FROM evaluated
ORDER BY period_sortable, stage, metric;
