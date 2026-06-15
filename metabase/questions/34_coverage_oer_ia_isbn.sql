-- name: Coverage — OER/IA Classifiability & ISBN (2024+)
-- display: table
-- description: How much of the catalog carries an ISBN and is OER/IA-classifiable. is_oer/is_ia are NULL exactly when FormatType is absent; classification is ISBN-structural, so internal inference fills 0 missing values (raising coverage needs an external ISBN→OER/IA source).
SELECT metric, value
FROM (
    SELECT 1 AS ord, 'sections total'                       AS metric, COUNT(*)                          AS value FROM master_section
    UNION ALL SELECT 2, 'sections w/ any ISBN material',               COUNT(*) FILTER (WHERE has_isbn)            FROM master_section
    UNION ALL SELECT 3, 'sections w/ any classified material',         COUNT(*) FILTER (WHERE has_formattype)      FROM master_section
    UNION ALL SELECT 4, 'materials w/ ISBN',                           SUM(isbn_count)                            FROM master_section
    UNION ALL SELECT 5, 'materials classified (has FormatType)',       SUM(classified_count)                      FROM master_section
) ORDER BY ord
