-- Supply (non-course-material) ISBN classification (#36): include-AND-NOT-exclude
-- title-keyword classifier. Canonical keyword list: sql/lookups/supply_keywords.tsv
-- (single source of truth; path relative to scripts/, both runners cd there first).
-- ISBN-level: an ISBN is a supply if ANY recent-term title variant matches >=1
-- include pattern AND 0 exclude patterns. Matching is substring LIKE over lowered
-- text — deliberately no word boundaries (see TSV notes). Attribution prefers a
-- specific keyword over the generic `>supply<` / `>suppy<` source markers, then
-- chooses the longest pattern and stable lexical tie-breaks. Method + per-keyword
-- precision (~0.98) was audited on Fall 2025; titles are period-independent, so
-- the flag applies to all periods.
--
-- Placed at Stage 1a before section enrollment so direct requiredness can be
-- supply-aware. Two consumers now — 1b_section_enrollment.sql and
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
    SELECT "ISBN13" AS isbn13, lower("Title") AS title_l, MIN("Title") AS title, COUNT(*) AS n_rows
    FROM ${SURVEY_TABLE}
    WHERE "ISBN13" IS NOT NULL
      AND "Title" IS NOT NULL
      AND period_sortable IN (SELECT period_sortable FROM recent_period)
    GROUP BY "ISBN13", lower("Title")
),
title_matches AS (
    SELECT
        it.isbn13,
        it.title_l,
        it.title,
        it.n_rows,
        inc.p AS matched_inc,
        inc.category,
        ROW_NUMBER() OVER (
            PARTITION BY it.isbn13, it.title_l
            ORDER BY (inc.p IN ('>supply<', '>suppy<')) ASC,
                     length(inc.p) DESC,
                     inc.p ASC,
                     inc.category ASC
        ) AS match_rank
    FROM isbn_title it
    JOIN inc ON it.title_l LIKE '%' || inc.p || '%'
    WHERE NOT EXISTS (SELECT 1 FROM exc WHERE it.title_l LIKE '%' || exc.p || '%')
),
classified AS (
    SELECT isbn13, title_l, title, n_rows, matched_inc, category
    FROM title_matches
    WHERE match_rank = 1
),
ranked AS (
    SELECT
        isbn13,
        title,
        SUM(n_rows) OVER (PARTITION BY isbn13) AS n_rows,
        matched_inc,
        category,
        ROW_NUMBER() OVER (
            PARTITION BY isbn13
            ORDER BY (matched_inc IN ('>supply<', '>suppy<')) ASC,
                     length(matched_inc) DESC,
                     matched_inc ASC,
                     title_l ASC,
                     title ASC,
                     category ASC
        ) AS attribution_rank
    FROM classified
)
SELECT
    isbn13,
    title,
    n_rows,
    matched_inc AS matched_pattern,
    category
FROM ranked
WHERE attribution_rank = 1;

CREATE INDEX idx_supply_isbn ON supply_isbn_classification (isbn13);

COMMIT;

-- Single-line console summary: supply ISBN count + the title rows they cover
SELECT 'supply ISBN classification (recent terms)' AS metric,
       COUNT(*) AS supply_isbns,
       SUM(n_rows) AS catalog_rows_covered
FROM supply_isbn_classification;
