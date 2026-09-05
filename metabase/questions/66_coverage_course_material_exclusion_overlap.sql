-- name: Coverage & Scope — Course Material Exclusion Overlap
-- display: table
-- description: Post-2024 canonical item groups; overlapping exclusion flags, not source rows. Current-snapshot overlap audit at the canonical course_material_post_2024 item-group grain (one period × section × ISBN audit group). Each row is an exact combination of independent Canada, supply, no-details, no-materials, and missing-ISBN flags; no mutually exclusive primary reason is imposed. included (no exclusions) is the zero-exclusion combination, while canonical_disposition exposes the canonical Use/NoUse result and population_classification_conflict separately exposes disagreement among source rows. reconstructed_source_rows returns to the enriched BMG source-row grain, while pct_of_term_item_groups uses canonical post-2024 item groups.

WITH flagged AS (
    SELECT
        period_sortable,
        unit_id,
        section_id,
        course_id,
        isbn13,
        source_row_count,
        COALESCE(is_canada, FALSE) AS is_canada,
        COALESCE(is_supply, FALSE) AS is_supply,
        COALESCE(no_details, FALSE) AS no_details,
        COALESCE(no_materials, FALSE) AS no_materials,
        NOT COALESCE(has_isbn, FALSE) AS is_missing_isbn,
        has_use_source_row,
        has_no_use_source_row,
        population_classification_conflict
    FROM course_material_post_2024
    WHERE 1 = 1
    [[ AND {{period_sortable}} ]]
), labeled AS (
    SELECT
        *,
        CASE
            WHEN NOT (is_canada OR is_supply OR no_details OR no_materials OR is_missing_isbn)
                THEN 'included (no exclusions)'
            ELSE CONCAT_WS(
                ' + ',
                CASE WHEN is_canada THEN 'Canada' END,
                CASE WHEN is_supply THEN 'supply' END,
                CASE WHEN no_details THEN 'no details' END,
                CASE WHEN no_materials THEN 'no materials' END,
                CASE WHEN is_missing_isbn THEN 'missing ISBN' END
            )
        END AS reason_combination,
        CASE
            WHEN has_use_source_row THEN 'Use'
            ELSE 'NoUse'
        END AS canonical_disposition
    FROM flagged
), grouped AS (
    SELECT
        period_sortable,
        is_canada,
        is_supply,
        no_details,
        no_materials,
        is_missing_isbn,
        reason_combination,
        canonical_disposition,
        population_classification_conflict,
        COUNT(*) AS item_groups,
        SUM(source_row_count) AS reconstructed_source_rows,
        COUNT(DISTINCT unit_id) AS institution_count,
        COUNT(DISTINCT section_id) AS section_count,
        COUNT(DISTINCT course_id) AS course_count,
        COUNT(DISTINCT isbn13) AS isbn_count
    FROM labeled
    GROUP BY
        period_sortable,
        is_canada,
        is_supply,
        no_details,
        no_materials,
        is_missing_isbn,
        reason_combination,
        canonical_disposition,
        population_classification_conflict
)
SELECT
    *,
    ROUND(100.0 * item_groups / NULLIF(SUM(item_groups) OVER (PARTITION BY period_sortable), 0), 2)
        AS pct_of_term_item_groups
FROM grouped
ORDER BY period_sortable, item_groups DESC, reason_combination
