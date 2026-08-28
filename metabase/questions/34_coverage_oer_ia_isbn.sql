-- name: Coverage — OER/IA Classifiability & ISBN (2024+)
-- display: table
-- description: ISBN and OER/IA-classification coverage among canonical material_costs items rolled into material-bearing Master Section rows. The section denominator is not the complete catalog or section_enrollment population; raising FormatType coverage requires an external ISBN→OER/IA source.
SELECT metric, value
FROM (
    SELECT 1 AS ord, 'sections total'                       AS metric, COUNT(*)                          AS value FROM master_section
    UNION ALL SELECT 2, 'sections w/ any ISBN material',               COUNT(*) FILTER (WHERE has_isbn)            FROM master_section
    UNION ALL SELECT 3, 'sections w/ any classified material',         COUNT(*) FILTER (WHERE has_formattype)      FROM master_section
    UNION ALL SELECT 4, 'materials w/ ISBN',                           SUM(isbn_count)                            FROM master_section
    UNION ALL SELECT 5, 'materials classified (has FormatType)',       SUM(classified_count)                      FROM master_section
) ORDER BY ord
