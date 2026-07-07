-- Supply (non-course-material) ISBN classification (#36): include-AND-NOT-exclude
-- title-keyword classifier. Canonical keyword list: sql/lookups/supply_keywords.tsv
-- (single source of truth; path relative to scripts/, both runners cd there first).
-- ISBN-level: an ISBN is a supply if ANY of its 2024+ title variants matches >=1
-- include pattern AND 0 exclude patterns. Matching is substring LIKE over lowered
-- text — deliberately no word boundaries (see TSV notes); longest matching include
-- pattern wins for attribution. Method + per-keyword precision (~0.98) were audited
-- on Fall 2025; titles are period-independent, so the flag applies to all periods.
--
-- Placed at Stage 1a (before 1b_section_filter.sql) for #40: has_required must be
-- supply-aware, so section_book_status needs supply_isbn_classification to exist
-- first. Two consumers now — 1b_section_filter.sql (has_required) and
-- 2_oer_classification.sql (comprehensive_data.is_supply) — hence the index. Depends
-- only on the raw catalog (built in 0_setup.sql) + the keyword TSV.

${CONFIG}

BEGIN TRANSACTION;

DROP TABLE IF EXISTS supply_isbn_classification;
CREATE TABLE supply_isbn_classification AS
WITH
inc AS (
    SELECT lower(pattern) AS p, category
    FROM read_csv('sql/lookups/supply_keywords.tsv', delim='\t', header=true,
        columns={'kind':'VARCHAR','pattern':'VARCHAR','category':'VARCHAR','precision_est':'VARCHAR','notes':'VARCHAR'})
    WHERE kind='include'
),
exc AS (
    SELECT lower(pattern) AS p
    FROM read_csv('sql/lookups/supply_keywords.tsv', delim='\t', header=true,
        columns={'kind':'VARCHAR','pattern':'VARCHAR','category':'VARCHAR','precision_est':'VARCHAR','notes':'VARCHAR'})
    WHERE kind='exclude'
),
isbn_title AS (
    SELECT "ISBN13" AS isbn13, lower("Title") AS title_l, ANY_VALUE("Title") AS title, COUNT(*) AS n_rows
    FROM ${SURVEY_TABLE}
    WHERE "ISBN13" IS NOT NULL AND "Title" IS NOT NULL AND period_date >= '2024-01-01'
    GROUP BY "ISBN13", lower("Title")
),
classified AS (
    SELECT it.isbn13, it.title, it.n_rows,
        (SELECT inc.p FROM inc WHERE it.title_l LIKE '%' || inc.p || '%' ORDER BY length(inc.p) DESC LIMIT 1) AS matched_inc,
        EXISTS (SELECT 1 FROM exc WHERE it.title_l LIKE '%' || exc.p || '%') AS hit_exc
    FROM isbn_title it
)
SELECT
    c.isbn13,
    ANY_VALUE(c.title)       AS title,
    SUM(c.n_rows)            AS n_rows,
    ANY_VALUE(c.matched_inc) AS matched_pattern,
    ANY_VALUE(i.category)    AS category
FROM classified c
LEFT JOIN inc i ON c.matched_inc = i.p
WHERE c.matched_inc IS NOT NULL AND NOT c.hit_exc
GROUP BY c.isbn13;

CREATE INDEX idx_supply_isbn ON supply_isbn_classification (isbn13);

COMMIT;

-- Single-line console summary: supply ISBN count + the title rows they cover
SELECT 'supply ISBN classification (2024+)' AS metric,
       COUNT(*) AS supply_isbns,
       SUM(n_rows) AS catalog_rows_covered
FROM supply_isbn_classification;
