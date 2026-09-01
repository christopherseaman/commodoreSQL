-- name: Coverage & Scope — Canonical Material Classification by Term
-- display: table
-- description: Current-snapshot classification frequencies over canonical material_costs Use items (one period × section × ISBN). A single source scan is expanded into six dimensions: catalog book_format, catalog FormatType, catalog book_status, inferred-required, OER, and IA. OER/IA NULLs are explicitly labeled unclassified. pct_of_term_dimension_items uses canonical item rows within each term and dimension, not source rows or sections.

WITH classified AS (
    SELECT
        period_sortable,
        section_id,
        course_id,
        unit_id,
        isbn13,
        book_format,
        format_type,
        book_status,
        is_required_inferred,
        is_oer,
        is_ia
    FROM material_costs
    WHERE 1 = 1
    [[ AND {{period_sortable}} ]]
), tall AS (
    SELECT
        classified.period_sortable,
        classified.section_id,
        classified.course_id,
        classified.unit_id,
        classified.isbn13,
        dimensions.dimension,
        dimensions.classification
    FROM classified
    CROSS JOIN LATERAL (
        VALUES
            ('Catalog book_format', COALESCE(NULLIF(TRIM(book_format), ''), '[unclassified book_format]')),
            ('Catalog FormatType', COALESCE(NULLIF(TRIM(format_type), ''), '[unclassified FormatType]')),
            ('Catalog book_status', COALESCE(NULLIF(TRIM(book_status), ''), '[unclassified book_status]')),
            ('Inferred required', CASE WHEN is_required_inferred THEN 'required (inferred)' ELSE 'not required (inferred)' END),
            ('OER status', CASE WHEN is_oer IS NULL THEN '[unclassified OER]' WHEN is_oer THEN 'OER' ELSE 'not OER' END),
            ('IA status', CASE WHEN is_ia IS NULL THEN '[unclassified IA]' WHEN is_ia THEN 'IA' ELSE 'not IA' END)
    ) AS dimensions(dimension, classification)
), grouped AS (
    SELECT
        period_sortable,
        dimension,
        classification,
        COUNT(*) AS item_count,
        COUNT(DISTINCT section_id) AS section_count,
        COUNT(DISTINCT course_id) AS course_count,
        COUNT(DISTINCT unit_id) AS institution_count,
        COUNT(DISTINCT isbn13) AS isbn_count
    FROM tall
    GROUP BY period_sortable, dimension, classification
)
SELECT
    *,
    ROUND(100.0 * item_count
        / NULLIF(SUM(item_count) OVER (PARTITION BY period_sortable, dimension), 0), 2)
        AS pct_of_term_dimension_items
FROM grouped
ORDER BY period_sortable, dimension, item_count DESC, classification
