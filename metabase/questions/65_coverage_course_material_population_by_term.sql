-- name: Coverage & Scope — Course Material Population by Term
-- display: table
-- description: Current-snapshot coverage from the canonical course_materials item-group spine (one period × section × ISBN, including one NULL-ISBN audit group per section), while reconstructed_source_rows sums source_row_count back to the enriched BMG source-row grain. All percentages named pct_*_of_item_groups use canonical item groups, not reconstructed source rows; Use-specific counts use the canonical retained Use population.

SELECT
    period_sortable,
    COUNT(*) AS item_groups,
    SUM(source_row_count) AS reconstructed_source_rows,
    COUNT(*) FILTER (WHERE is_post_2024) AS post_2024_item_groups,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_post_2024), 0) AS post_2024_reconstructed_source_rows,
    COUNT(*) FILTER (WHERE is_course_material_use) AS use_item_groups,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_course_material_use), 0) AS use_reconstructed_source_rows,
    COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_item_groups,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_course_material_no_use), 0) AS no_use_reconstructed_source_rows,
    COUNT(*) FILTER (WHERE is_post_2024 AND is_canada) AS canada_item_groups,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_post_2024 AND is_canada), 0) AS canada_reconstructed_source_rows,
    COUNT(*) FILTER (WHERE is_post_2024 AND is_supply) AS supply_item_groups,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_post_2024 AND is_supply), 0) AS supply_reconstructed_source_rows,
    COUNT(*) FILTER (WHERE is_post_2024 AND NOT has_isbn) AS missing_isbn_item_groups,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_post_2024 AND NOT has_isbn), 0)
        AS missing_isbn_reconstructed_source_rows,
    COUNT(*) FILTER (WHERE is_post_2024 AND no_details) AS no_details_item_groups,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_post_2024 AND no_details), 0)
        AS no_details_reconstructed_source_rows,
    COUNT(*) FILTER (WHERE is_post_2024 AND no_materials) AS no_materials_item_groups,
    COALESCE(SUM(source_row_count) FILTER (WHERE is_post_2024 AND no_materials), 0)
        AS no_materials_reconstructed_source_rows,
    COUNT(DISTINCT unit_id) AS institution_count,
    COUNT(DISTINCT section_id) AS section_count,
    COUNT(DISTINCT course_id) AS course_count,
    COUNT(DISTINCT isbn13) AS isbn_count,
    COUNT(DISTINCT unit_id) FILTER (WHERE is_course_material_use) AS use_institution_count,
    COUNT(DISTINCT section_id) FILTER (WHERE is_course_material_use) AS use_section_count,
    COUNT(DISTINCT course_id) FILTER (WHERE is_course_material_use) AS use_course_count,
    COUNT(DISTINCT isbn13) FILTER (WHERE is_course_material_use) AS use_isbn_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_post_2024) / NULLIF(COUNT(*), 0), 2)
        AS pct_post_2024_of_item_groups,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_post_2024 AND is_course_material_use)
        / NULLIF(COUNT(*) FILTER (WHERE is_post_2024), 0), 2)
        AS pct_use_of_post_2024_item_groups,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_post_2024 AND is_course_material_no_use)
        / NULLIF(COUNT(*) FILTER (WHERE is_post_2024), 0), 2)
        AS pct_no_use_of_post_2024_item_groups,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_post_2024 AND NOT has_isbn)
        / NULLIF(COUNT(*) FILTER (WHERE is_post_2024), 0), 2)
        AS pct_missing_isbn_of_post_2024_item_groups,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_post_2024 AND is_canada)
        / NULLIF(COUNT(*) FILTER (WHERE is_post_2024), 0), 2)
        AS pct_canada_of_post_2024_item_groups,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_post_2024 AND is_supply)
        / NULLIF(COUNT(*) FILTER (WHERE is_post_2024), 0), 2)
        AS pct_supply_of_post_2024_item_groups,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_post_2024 AND no_details)
        / NULLIF(COUNT(*) FILTER (WHERE is_post_2024), 0), 2)
        AS pct_no_details_of_post_2024_item_groups,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_post_2024 AND no_materials)
        / NULLIF(COUNT(*) FILTER (WHERE is_post_2024), 0), 2)
        AS pct_no_materials_of_post_2024_item_groups
FROM course_materials
WHERE 1 = 1
[[ AND {{period_sortable}} ]]
GROUP BY period_sortable
ORDER BY period_sortable
