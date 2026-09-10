-- name: Fall 2025 — Pricing ↔ Catalog Population Accounting
-- display: table
-- description: Two-direction Fall 2025 accounting with separate denominators. Pricing rows are retained pricing_historical observations grouped to the production section_id × ISBN key; canonical rows are course_material keys split by Use/NoUse. Exact section × ISBN matching takes precedence even for source composites containing UNKNOWN. Institution/term/ISBN candidates are evidence only, not accepted matches or proof of a section-encoding cause. Invalid and no-source buckets apply only to unmatched keys. raw_required_key_count uses pricing-owned book_status evidence; no catalog requiredness is assigned to pricing.

WITH pricing_key_metadata AS (
    SELECT
        section_id,
        isbn13,
        CASE WHEN COUNT(period_sortable) = COUNT(*)
                   AND COUNT(DISTINCT period_sortable) = 1
             THEN ANY_VALUE(period_sortable) END AS period_sortable,
        CASE WHEN COUNT(unit_id) = COUNT(*) AND COUNT(DISTINCT unit_id) = 1
             THEN ANY_VALUE(unit_id) END AS unit_id,
        COUNT(*) AS observation_count,
        COALESCE(BOOL_OR(required), FALSE) AS is_required_raw,
        COUNT(period_sortable) <> COUNT(*) OR COUNT(DISTINCT period_sortable) <> 1
          OR COUNT(unit_id) <> COUNT(*) OR COUNT(DISTINCT unit_id) <> 1
          OR section_id IS NULL OR section_id LIKE '%UNKNOWN%'
          OR isbn13 IS NULL OR TRIM(isbn13) IN ('', '0')
          OR TRY_CAST(isbn13 AS BIGINT) IS NULL AS invalid_key
    FROM pricing_historical
    GROUP BY section_id, isbn13
), pricing_keys AS (
    SELECT * FROM pricing_key_metadata WHERE period_sortable = '2025-4'
), catalog_keys AS (
    SELECT
        period_sortable, section_id, unit_id, CAST(isbn13 AS VARCHAR) AS isbn13,
        is_course_material_use, is_course_material_no_use, source_row_count,
        period_sortable IS NULL OR unit_id IS NULL OR section_id IS NULL OR isbn13 IS NULL
          OR section_id LIKE '%UNKNOWN%' AS invalid_key
    FROM course_material
    WHERE period_sortable = '2025-4'
), catalog_candidates AS (
    SELECT unit_id, isbn13,
           COUNT(*) FILTER (WHERE is_course_material_use) AS use_sections,
           COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_sections
    FROM catalog_keys
    WHERE NOT invalid_key
    GROUP BY unit_id, isbn13
), pricing_candidates AS (
    SELECT unit_id, isbn13, COUNT(*) AS pricing_sections
    FROM pricing_keys
    WHERE NOT invalid_key
    GROUP BY unit_id, isbn13
), pricing_accounted AS (
    SELECT p.*,
        CASE
          WHEN c.is_course_material_use THEN 'exact catalog Use'
          WHEN c.is_course_material_no_use THEN 'exact catalog NoUse'
          WHEN p.invalid_key THEN 'invalid unmatched pricing key'
          WHEN COALESCE(i.use_sections, 0) > 0 THEN 'institution/term/ISBN candidate to Use'
          WHEN COALESCE(i.no_use_sections, 0) > 0 THEN 'institution/term/ISBN candidate to NoUse'
          ELSE 'no catalog institution/term/ISBN counterpart'
        END AS reason,
        COALESCE(i.use_sections, 0) + COALESCE(i.no_use_sections, 0) AS candidates
    FROM pricing_keys p
    LEFT JOIN catalog_keys c
      ON p.section_id = c.section_id AND p.isbn13 = c.isbn13
    LEFT JOIN catalog_candidates i
      ON p.unit_id = i.unit_id AND p.isbn13 = i.isbn13
), catalog_accounted AS (
    SELECT c.*,
        CASE
          WHEN p.section_id IS NOT NULL THEN 'exact pricing'
          WHEN c.invalid_key THEN 'invalid unmatched canonical key'
          WHEN COALESCE(i.pricing_sections, 0) > 0 THEN 'institution/term/ISBN candidate'
          ELSE 'no pricing institution/term/ISBN source'
        END AS reason,
        COALESCE(i.pricing_sections, 0) AS candidates
    FROM catalog_keys c
    LEFT JOIN pricing_keys p
      ON c.section_id = p.section_id AND c.isbn13 = p.isbn13
    LEFT JOIN pricing_candidates i
      ON c.unit_id = i.unit_id AND c.isbn13 = i.isbn13
)
SELECT
    'pricing → catalog' AS direction,
    reason,
    COUNT(*) AS key_count,
    SUM(observation_count)::BIGINT AS source_row_count,
    COUNT(*) FILTER (WHERE is_required_raw) AS raw_required_key_count,
    COUNT(*) FILTER (WHERE reason LIKE 'institution/term/ISBN candidate%'
                       AND candidates > 1) AS ambiguous_candidate_key_count
FROM pricing_accounted
GROUP BY reason
UNION ALL
SELECT
    CASE WHEN is_course_material_use THEN 'canonical Use → pricing'
         ELSE 'canonical NoUse → pricing' END AS direction,
    reason,
    COUNT(*) AS key_count,
    SUM(source_row_count)::BIGINT AS source_row_count,
    NULL::BIGINT AS raw_required_key_count,
    COUNT(*) FILTER (WHERE reason = 'institution/term/ISBN candidate'
                       AND candidates > 1) AS ambiguous_candidate_key_count
FROM catalog_accounted
GROUP BY direction, reason
ORDER BY direction, reason
