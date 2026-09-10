-- name: Fall 2025 — Pricing ↔ Catalog Candidate Examples
-- display: table
-- description: Deterministic sample of 20 unmatched retained pricing section × ISBN keys that have catalog rows at the same institution, term, and ISBN. Pricing department/course/section/CRN identifiers and candidate catalog section IDs remain source-visible. Agreement at institution × term × ISBN is candidate evidence only: it neither proves the mismatch cause nor chooses a crosswalk. candidate_catalog_section_count exposes ambiguity; no fallback is applied.

WITH pricing_key_metadata AS (
    SELECT
        section_id,
        isbn13,
        CASE WHEN COUNT(period_sortable) = COUNT(*)
                   AND COUNT(DISTINCT period_sortable) = 1
             THEN ANY_VALUE(period_sortable) END AS period_sortable,
        CASE WHEN COUNT(unit_id) = COUNT(*) AND COUNT(DISTINCT unit_id) = 1
             THEN ANY_VALUE(unit_id) END AS unit_id,
        MIN(dept_code) AS pricing_department,
        MIN(course_code) AS pricing_course,
        MIN(section_code) AS pricing_section,
        MIN(crn) AS pricing_crn,
        COUNT(*) AS retained_pricing_observation_count,
        COUNT(DISTINCT dept_code) AS pricing_department_variant_count,
        COUNT(DISTINCT course_code) AS pricing_course_variant_count,
        COUNT(DISTINCT section_code) AS pricing_section_variant_count,
        COUNT(DISTINCT crn) AS pricing_crn_variant_count,
        COUNT(period_sortable) = COUNT(*) AND COUNT(DISTINCT period_sortable) = 1
          AND COUNT(unit_id) = COUNT(*) AND COUNT(DISTINCT unit_id) = 1
          AND section_id IS NOT NULL AND section_id NOT LIKE '%UNKNOWN%'
          AND isbn13 IS NOT NULL AND TRIM(isbn13) NOT IN ('', '0')
          AND TRY_CAST(isbn13 AS BIGINT) IS NOT NULL AS valid_key
    FROM pricing_historical
    GROUP BY section_id, isbn13
), catalog_keys AS (
    SELECT
        period_sortable, section_id, unit_id, CAST(isbn13 AS VARCHAR) AS isbn13,
        is_course_material_use
    FROM course_material
    WHERE period_sortable = '2025-4'
      AND period_sortable IS NOT NULL AND unit_id IS NOT NULL
      AND section_id IS NOT NULL AND section_id NOT LIKE '%UNKNOWN%'
      AND isbn13 IS NOT NULL
), unmatched_candidates AS (
    SELECT p.*
    FROM pricing_key_metadata p
    WHERE p.period_sortable = '2025-4' AND p.valid_key
      AND NOT EXISTS (
          SELECT 1 FROM catalog_keys c
          WHERE c.section_id = p.section_id AND c.isbn13 = p.isbn13
      )
      AND EXISTS (
          SELECT 1 FROM catalog_keys c
          WHERE c.unit_id = p.unit_id AND c.isbn13 = p.isbn13
      )
    ORDER BY p.unit_id, p.isbn13, p.section_id
    LIMIT 20
)
SELECT
    p.unit_id,
    p.isbn13,
    p.pricing_department,
    p.pricing_course,
    p.pricing_section,
    p.pricing_crn,
    p.section_id AS pricing_section_id,
    p.retained_pricing_observation_count,
    p.pricing_department_variant_count,
    p.pricing_course_variant_count,
    p.pricing_section_variant_count,
    p.pricing_crn_variant_count,
    COUNT(*) AS candidate_catalog_section_count,
    COUNT(*) FILTER (WHERE c.is_course_material_use) AS candidate_use_section_count,
    LIST(c.section_id ORDER BY c.section_id) AS candidate_catalog_section_ids
FROM unmatched_candidates p
JOIN catalog_keys c
  ON p.unit_id = c.unit_id AND p.isbn13 = c.isbn13
GROUP BY ALL
ORDER BY p.unit_id, p.isbn13, p.section_id
