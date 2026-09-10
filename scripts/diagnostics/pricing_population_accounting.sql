-- Investigation only; not part of the ETL runner.
-- Two-direction accounting at retained pricing-key and canonical material-key grain.
-- duckdb -bail -readonly -csv duckdb/commodore.duckdb < scripts/diagnostics/pricing_population_accounting.sql
SET threads=2;
SET memory_limit='4GB';

CREATE TEMP TABLE pricing_keys AS
SELECT
    section_id,
    isbn13,
    CASE WHEN COUNT(period_sortable) = COUNT(*) AND COUNT(DISTINCT period_sortable) = 1
      THEN ANY_VALUE(period_sortable) END
      AS period_sortable,
    CASE WHEN COUNT(unit_id) = COUNT(*) AND COUNT(DISTINCT unit_id) = 1
      THEN ANY_VALUE(unit_id) END AS unit_id,
    ANY_VALUE(dept_code) AS dept_code,
    ANY_VALUE(course_code) AS course_code,
    ANY_VALUE(section_code) AS section_code,
    ANY_VALUE(crn) AS crn,
    COUNT(*) AS observation_count,
    COALESCE(BOOL_OR(required), FALSE) AS is_required_raw,
    COUNT(period_sortable) <> COUNT(*) OR COUNT(DISTINCT period_sortable) <> 1
      OR COUNT(unit_id) <> COUNT(*) OR COUNT(DISTINCT unit_id) <> 1
      OR section_id IS NULL
      OR section_id LIKE '%UNKNOWN%' OR isbn13 IS NULL OR TRIM(isbn13) IN ('', '0')
      OR TRY_CAST(isbn13 AS BIGINT) IS NULL AS invalid_key
FROM pricing_historical
GROUP BY section_id, isbn13;

CREATE TEMP TABLE catalog_keys AS
SELECT
    period_sortable, section_id, unit_id, CAST(isbn13 AS VARCHAR) AS isbn13,
    is_recent, is_course_material_use, is_course_material_no_use, source_row_count,
    is_supply, no_details, no_materials, is_canada,
    period_sortable IS NULL OR unit_id IS NULL OR section_id IS NULL OR isbn13 IS NULL
      OR section_id LIKE '%UNKNOWN%' AS invalid_key
FROM course_material;

CREATE TEMP TABLE catalog_institution_candidates AS
SELECT
    period_sortable, unit_id, isbn13,
    COUNT(*) FILTER (WHERE is_course_material_use) AS use_sections,
    COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_sections
FROM catalog_keys
WHERE NOT invalid_key
GROUP BY period_sortable, unit_id, isbn13;

CREATE TEMP TABLE pricing_institution_candidates AS
SELECT period_sortable, unit_id, isbn13, COUNT(*) AS pricing_sections
FROM pricing_keys
WHERE NOT invalid_key
GROUP BY period_sortable, unit_id, isbn13;

CREATE TEMP TABLE pricing_accounted AS
SELECT
    p.*,
    c.is_course_material_use AS exact_use,
    c.is_course_material_no_use AS exact_no_use,
    COALESCE(i.use_sections, 0) AS candidate_use_sections,
    COALESCE(i.no_use_sections, 0) AS candidate_no_use_sections,
    CASE
      WHEN c.is_course_material_use THEN 'exact catalog Use'
      WHEN c.is_course_material_no_use THEN 'exact catalog NoUse'
      WHEN p.invalid_key THEN 'invalid unmatched pricing key'
      WHEN COALESCE(i.use_sections, 0) > 0 THEN 'institution/term/ISBN candidate to Use'
      WHEN COALESCE(i.no_use_sections, 0) > 0 THEN 'institution/term/ISBN candidate to NoUse'
      ELSE 'no catalog institution/term/ISBN counterpart'
    END AS reason
FROM pricing_keys p
LEFT JOIN catalog_keys c
  ON p.section_id = c.section_id
 AND p.isbn13 = c.isbn13
LEFT JOIN catalog_institution_candidates i
  ON p.period_sortable = i.period_sortable
 AND p.unit_id = i.unit_id
 AND p.isbn13 = i.isbn13;

-- Pricing side: retained observations and distinct section/ISBN keys. These are
-- not material counts and are not comparable to the Fall 2025 fallback totals.
SELECT
    'pricing_to_catalog' AS direction, period_sortable, reason,
    COUNT(*) AS pricing_keys,
    SUM(observation_count)::BIGINT AS retained_pricing_observations,
    COUNT(*) FILTER (WHERE is_required_raw) AS raw_required_keys,
    COUNT(*) FILTER (WHERE reason LIKE 'institution/term/ISBN candidate%'
                       AND candidate_use_sections + candidate_no_use_sections > 1)
      AS ambiguous_catalog_candidate_keys
FROM pricing_accounted
GROUP BY period_sortable, reason
ORDER BY period_sortable, reason;

CREATE TEMP TABLE catalog_accounted AS
SELECT
    c.*,
    p.section_id IS NOT NULL AS exact_pricing,
    COALESCE(i.pricing_sections, 0) AS candidate_pricing_sections,
    CASE
      WHEN p.section_id IS NOT NULL THEN 'exact pricing'
      WHEN c.invalid_key THEN 'invalid unmatched canonical key'
      WHEN COALESCE(i.pricing_sections, 0) > 0 THEN 'institution/term/ISBN candidate'
      ELSE 'no pricing institution/term/ISBN source'
    END AS pricing_reason
FROM catalog_keys c
LEFT JOIN pricing_keys p
  ON c.section_id = p.section_id
 AND c.isbn13 = p.isbn13
LEFT JOIN pricing_institution_candidates i
  ON c.period_sortable = i.period_sortable
 AND c.unit_id = i.unit_id
 AND c.isbn13 = i.isbn13;

-- Catalog side: grouping and Use/NoUse happen before pricing enrichment. The
-- missing-price denominator requested by #21 is canonical Use keys only.
SELECT
    'catalog_to_pricing' AS direction, period_sortable,
    CASE WHEN is_course_material_use THEN 'Use'
         WHEN is_course_material_no_use THEN 'NoUse'
         ELSE 'outside recent window' END AS population,
    pricing_reason AS reason,
    COUNT(*) AS canonical_material_keys,
    SUM(source_row_count)::BIGINT AS grouped_catalog_source_rows,
    COUNT(*) FILTER (WHERE pricing_reason = 'institution/term/ISBN candidate'
                       AND candidate_pricing_sections > 1)
      AS ambiguous_pricing_candidate_keys
FROM catalog_accounted
GROUP BY period_sortable, population, pricing_reason
ORDER BY period_sortable, population, pricing_reason;

-- Rows rejected before canonical grouping are kept separate from grouped keys.
SELECT
    'catalog_rows_before_grouping' AS metric,
    COUNT(*) AS catalog_source_rows,
    COUNT(*) FILTER (WHERE period_sortable IS NULL) AS null_period_rows,
    COUNT(*) FILTER (WHERE section_id IS NULL OR section_id LIKE '%UNKNOWN%')
      AS invalid_section_key_rows
FROM comprehensive_data;

-- Overlapping NoUse reasons are intentionally not forced into a false hierarchy.
SELECT
    'canonical_grouping_and_filtering' AS metric, period_sortable,
    COUNT(*) AS canonical_keys,
    SUM(source_row_count)::BIGINT AS catalog_source_rows,
    COUNT(*) FILTER (WHERE is_course_material_use) AS use_keys,
    COUNT(*) FILTER (WHERE is_course_material_no_use) AS no_use_keys,
    COUNT(*) FILTER (WHERE is_course_material_no_use AND isbn13 IS NULL) AS no_isbn_keys,
    COUNT(*) FILTER (WHERE is_course_material_no_use AND is_supply) AS supply_keys,
    COUNT(*) FILTER (WHERE is_course_material_no_use AND no_details) AS no_details_keys,
    COUNT(*) FILTER (WHERE is_course_material_no_use AND no_materials) AS no_materials_keys,
    COUNT(*) FILTER (WHERE is_course_material_no_use AND is_canada) AS canada_keys
FROM course_material
WHERE is_recent
GROUP BY period_sortable
ORDER BY period_sortable;

-- Representative candidate evidence only. This does not establish which source
-- component differs. CRN is retained as evidence, not treated as an automatic crosswalk.
CREATE TEMP TABLE example_pricing_keys AS
SELECT * FROM pricing_accounted
WHERE period_sortable = '2025-4'
  AND reason LIKE 'institution/term/ISBN candidate%'
ORDER BY unit_id, isbn13, section_id
LIMIT 20;

SELECT
    'institution_term_isbn_candidate_examples' AS metric,
    p.period_sortable, p.unit_id, p.isbn13,
    p.dept_code AS pricing_department, p.course_code AS pricing_course,
    p.section_code AS pricing_section, p.crn AS pricing_crn,
    p.section_id AS pricing_section_id,
    LIST(c.section_id ORDER BY c.section_id) AS catalog_section_ids
FROM example_pricing_keys p
JOIN catalog_keys c
  ON p.period_sortable = c.period_sortable
 AND p.unit_id = c.unit_id
 AND p.isbn13 = c.isbn13
WHERE p.reason LIKE 'institution/term/ISBN candidate%'
GROUP BY ALL
ORDER BY p.period_sortable DESC, p.unit_id, p.isbn13, p.section_id
LIMIT 20;
