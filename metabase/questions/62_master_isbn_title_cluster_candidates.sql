-- name: Master ISBN -- title-cluster blessed-ISBN13 candidates (Fall 2025)
-- display: table
-- description: BMG issue #45 part (b)/(c), over raw Fall-2025 comprehensive_data rows with non-null ISBN13 and nonblank normalized Title; no canonical #58 Use or is_supply filter is applied. Since ISBN13-side variability is empirically zero (see the companion per-ISBN13 variability card -- 0 rows), the real 'same book listed many ways' problem runs the other direction: one normalized title (LOWER(TRIM(Title))) spread across many distinct ISBN13s. One row per normalized title with more than one distinct ISBN13 (36,691 titles as of this run). n_isbn13 = distinct ISBN13 count under the title; n_authors = distinct normalized Author strings across ALL rows under the title (not per-ISBN13); author_diversity_ratio = n_authors/n_isbn13, an UNVALIDATED review diagnostic only (low ratio, e.g. under 0.05, tends to flag non-identifying placeholder titles like 'Cognella Textbook'; high ratio, e.g. 0.4+, tends to reflect genuinely distinct books sharing a generic title like 'Macroeconomics' -- do NOT auto-collapse on this alone, per the #45 caution that a precision-estimated rule, following the #36 supply-classifier precedent, is still needed). blessed_isbn13/title/author/publisher/rows = the ISBN13 with the most catalog rows (adoption count) within the title cluster, i.e. the proposed canonical/modal candidate; every other ISBN13 in the cluster is an implicit non-blessed/duplicate candidate. Across all 36,691 clusters, 69,339 ISBN13s (417,112 rows) are non-blessed candidates; 17,894 clusters (40,645 ISBN13s) have n_authors=1, the strongest same-book signal. This is a REVIEW CANDIDATE list for BMG/Jeff sign-off, not an applied correction -- no pipeline table or column has been changed. Blank-ISBN13 rows are excluded (cannot be keyed by ISBN13, ~54% of catalog).
WITH rows_norm AS (
    SELECT
        LOWER(TRIM(c."Title"))   AS title_norm,
        c."ISBN13"               AS isbn13,
        LOWER(TRIM(c."Author"))  AS author_norm,
        c."Title"                AS title_raw,
        c."Author"               AS author_raw,
        c."Publisher"            AS publisher_raw
    FROM comprehensive_data c
    WHERE c.period_sortable = '2025-4'
      AND c."ISBN13" IS NOT NULL
      AND c."Title" IS NOT NULL
      AND TRIM(c."Title") <> ''
),
per_isbn AS (
    SELECT
        title_norm,
        isbn13,
        COUNT(*)                                     AS isbn_rows,
        MODE(title_raw)                               AS isbn_title,
        MODE(author_raw)                              AS isbn_author,
        MODE(publisher_raw) FILTER (WHERE publisher_raw IS NOT NULL AND publisher_raw <> '') AS isbn_publisher
    FROM rows_norm
    GROUP BY title_norm, isbn13
),
per_title AS (
    SELECT
        title_norm,
        COUNT(DISTINCT isbn13) AS n_isbn13,
        SUM(isbn_rows)         AS n_rows_total
    FROM per_isbn
    GROUP BY title_norm
),
title_authors AS (
    SELECT
        title_norm,
        COUNT(DISTINCT author_norm) AS n_authors
    FROM rows_norm
    GROUP BY title_norm
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY title_norm ORDER BY isbn_rows DESC, isbn13) AS rn
    FROM per_isbn
)
SELECT
    t.title_norm                                AS title_normalized,
    t.n_isbn13,
    a.n_authors,
    ROUND(a.n_authors::DOUBLE / t.n_isbn13, 3)   AS author_diversity_ratio,
    t.n_rows_total,
    r.isbn13                                    AS blessed_isbn13,
    r.isbn_title                                AS blessed_title,
    r.isbn_author                               AS blessed_author,
    r.isbn_publisher                            AS blessed_publisher,
    r.isbn_rows                                 AS blessed_isbn_rows
FROM per_title t
JOIN title_authors a ON a.title_norm = t.title_norm
JOIN ranked r ON r.title_norm = t.title_norm AND r.rn = 1
WHERE t.n_isbn13 > 1
ORDER BY t.n_isbn13 DESC;
