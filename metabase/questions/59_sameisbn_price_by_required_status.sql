-- name: Fall 2025 — Same-ISBN Price by Required Status (is_required_inferred)
-- display: table
-- description: Fall-2025 BMG priced Use adoptions; ≥10/ISBN, both inferred-required statuses. Issue #44: is the same ISBN priced differently when required vs optional/supplemental? For every Fall 2025 BMG-scope (period_sortable=2025-4, 4 intro/intermediate course levels, 6 real teaching sectors) canonical Use priced (section,isbn) adoption from master_material, demeans price_min by that SAME ISBN's own overall median price_min. master_material is already canonical at (period_sortable, section_id, isbn13), so catalog-row multiplicity cannot multiply pricing observations. Included ISBNs need >=10 total adoptions AND at least 1 adoption in each required status: 13,772 ISBNs and 573,151 adoptions. required_status uses canonical is_required_inferred for the section/ISBN. raw_median/mean_price show the unconditional gap (course-mix and book-identity effects included); median/mean_vs_same_isbn_baseline isolate the same-item effect by removing book identity. FINDING: raw median price is $9.14 higher for required ($63.99 vs $54.85, +16.7%), but the same-ISBN median residual is $0.00 for both groups and mean residuals differ by only $0.07 ($0.40 required vs $0.47 optional/supplemental). The raw gap is mainly a course-mix effect, not an economically meaningful same-item pricing effect. price_min is the cheapest available option (buy or rent, any condition/format) from master_material. Confounds not controlled: institution/state/program mix within the pooled same-ISBN baseline — see GitHub issue #44 for deep-dive caveats.
WITH adopt AS (
  SELECT section_id, CAST(isbn13 AS VARCHAR) AS isbn13,
    is_required_inferred AS is_required, price_min
  FROM master_material
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
    AND price_min IS NOT NULL
),
isbn_stats AS (
  SELECT isbn13,
    MEDIAN(price_min) AS isbn_median
  FROM adopt
  GROUP BY isbn13
  HAVING COUNT(*) >= 10
    AND COUNT(*) FILTER (WHERE is_required) > 0
    AND COUNT(*) FILTER (WHERE NOT is_required) > 0
),
demeaned AS (
  SELECT a.isbn13, a.is_required, a.price_min, a.price_min - m.isbn_median AS d_price
  FROM adopt a
  JOIN isbn_stats m ON a.isbn13 = m.isbn13
)
SELECT
  CASE WHEN is_required THEN 'required' ELSE 'optional_or_supplemental' END AS required_status,
  COUNT(*) AS adoptions,
  COUNT(DISTINCT isbn13) AS distinct_isbns_matched,
  ROUND(MEDIAN(price_min), 2) AS raw_median_price,
  ROUND(AVG(price_min), 2) AS raw_mean_price,
  ROUND(MEDIAN(d_price), 2) AS median_vs_same_isbn_baseline,
  ROUND(AVG(d_price), 2) AS mean_vs_same_isbn_baseline,
  ROUND(quantile_cont(d_price, 0.25), 2) AS p25_vs_baseline,
  ROUND(quantile_cont(d_price, 0.75), 2) AS p75_vs_baseline
FROM demeaned
GROUP BY is_required
ORDER BY is_required DESC
