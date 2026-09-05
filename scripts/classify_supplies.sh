#!/bin/bash
set -euo pipefail

# Supply (non-course-material) ISBN classifier for the BMG analysis (issue #36).
#
# A material is a SUPPLY iff its title matches >=1 INCLUDE keyword AND 0 EXCLUDE keywords
# (include-and-not-exclude two-list classifier). Keywords live in the canonical lookup
# scripts/sql/lookups/supply_keywords.tsv (single source of truth). Read-only; coexists
# with Metabase. Writes the supply ISBN set to output/ and prints prevalence + cost impact.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$SCRIPT_DIR/dot.env" ]; then set -o allexport; source "$SCRIPT_DIR/dot.env"; set +o allexport; fi
DB="${MAIN_DB:-$REPO_ROOT/duckdb/commodore.duckdb}"
DUCKDB="${DUCKDB:-duckdb}"
LOOKUP="$REPO_ROOT/scripts/sql/lookups/supply_keywords.tsv"
OUT="$REPO_ROOT/output/fall2025_supply_isbns.parquet"
mkdir -p "$REPO_ROOT/output"

echo "[1/2] Classifying supply ISBNs (Fall 2025) -> output/fall2025_supply_isbns.parquet"
$DUCKDB -bail -readonly "$DB" <<SQL
SET memory_limit='12GB'; SET threads=6;
COPY (
  WITH
  inc AS (SELECT lower(pattern) AS p, category FROM read_csv('${LOOKUP}', delim='\t', header=true, columns={'kind':'VARCHAR','pattern':'VARCHAR','category':'VARCHAR','precision_est':'VARCHAR','notes':'VARCHAR'}) WHERE kind='include'),
  exc AS (SELECT lower(pattern) AS p FROM read_csv('${LOOKUP}', delim='\t', header=true, columns={'kind':'VARCHAR','pattern':'VARCHAR','category':'VARCHAR','precision_est':'VARCHAR','notes':'VARCHAR'}) WHERE kind='exclude'),
  isbn_title AS (
    SELECT "ISBN13" AS isbn13, lower("Title") AS title_l, MIN("Title") AS title, COUNT(*) AS n_rows
    FROM comprehensive_data
    WHERE period_sortable='2025-4' AND "ISBN13" IS NOT NULL AND "Title" IS NOT NULL
    GROUP BY "ISBN13", lower("Title")
  ),
  title_matches AS (
    SELECT it.isbn13, it.title_l, it.title, it.n_rows,
      inc.p AS matched_inc, inc.category,
      ROW_NUMBER() OVER (
        PARTITION BY it.isbn13, it.title_l
        ORDER BY (inc.p IN ('>supply<', '>suppy<')) ASC,
                 length(inc.p) DESC, inc.p ASC, inc.category ASC
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
    SELECT isbn13, title,
      SUM(n_rows) OVER (PARTITION BY isbn13) AS n_rows,
      matched_inc, category,
      ROW_NUMBER() OVER (
        PARTITION BY isbn13
        ORDER BY (matched_inc IN ('>supply<', '>suppy<')) ASC,
                 length(matched_inc) DESC, matched_inc ASC,
                 title_l ASC, title ASC, category ASC
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
  WHERE attribution_rank = 1
) TO '${OUT}' (FORMAT PARQUET);
SQL

echo ""
echo "[2/2] Prevalence, category mix, precision sample, and cost impact"
$DUCKDB -bail -readonly "$DB" <<SQL
SET memory_limit='12GB'; SET threads=6;
.mode box
-- Prevalence vs all Fall-2025 priced/scoped materials
WITH tot AS (
  SELECT COUNT(DISTINCT "ISBN13") AS isbns, COUNT(*) AS rows
  FROM comprehensive_data WHERE period_sortable='2025-4' AND "ISBN13" IS NOT NULL
)
SELECT 'supply ISBNs' AS metric, (SELECT COUNT(*) FROM read_parquet('${OUT}'))::VARCHAR AS value,
       ROUND(100.0*(SELECT COUNT(*) FROM read_parquet('${OUT}'))/(SELECT isbns FROM tot),2)::VARCHAR || '% of Fall-2025 ISBNs' AS share
UNION ALL
SELECT 'supply adoption rows', (SELECT SUM(n_rows) FROM read_parquet('${OUT}'))::VARCHAR,
       ROUND(100.0*(SELECT SUM(n_rows) FROM read_parquet('${OUT}'))/(SELECT rows FROM tot),2)::VARCHAR || '% of Fall-2025 rows';

-- Category mix
SELECT category, COUNT(*) AS supply_isbns, SUM(n_rows) AS adoption_rows
FROM read_parquet('${OUT}') GROUP BY category ORDER BY adoption_rows DESC;

-- Precision spot-check: 30 pseudo-random flagged titles (NOT by popularity)
SELECT title, n_rows, matched_pattern, category
FROM read_parquet('${OUT}') ORDER BY hash(isbn13) LIMIT 30;

-- Cost impact: required supply materials in the BMG scope, by class.
-- How many priced REQUIRED materials are supplies, and what do they cost (per-item median)?
WITH scope AS (
  SELECT section_id, control,
    CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl
  FROM master_section
  WHERE period_sortable='2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
),
supply_req AS (
  SELECT DISTINCT s.section_id, c."ISBN13" AS isbn13, (pw.price_min + pw.price_max)/2.0 AS price_avg
  FROM scope s
  JOIN comprehensive_data c ON c.section_id = s.section_id AND c.period_sortable='2025-4' AND c.is_required_inferred
  JOIN read_parquet('${OUT}') sup ON c."ISBN13" = sup.isbn13
  JOIN pricing_wide pw ON pw.section_id = c.section_id AND pw.isbn13 = c."ISBN13"
)
SELECT s.control, s.lvl,
  COUNT(*) FILTER (WHERE sr.isbn13 IS NOT NULL) AS supply_required_materials,
  COUNT(DISTINCT sr.section_id) AS sections_with_supply_required,
  ROUND(MEDIAN(sr.price_avg), 2) AS supply_item_price_median,
  ROUND(MAX(sr.price_avg), 2) AS supply_item_price_max
FROM scope s LEFT JOIN supply_req sr ON s.section_id = sr.section_id
GROUP BY s.control, s.lvl ORDER BY s.control, s.lvl;
SQL
