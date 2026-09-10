-- name: Fall 2025 — Same-ISBN Price by Literal book_status (required vs option/recommended)
-- display: table
-- description: Fall-2025 BMG priced Use adoptions; ≥10/ISBN, both literal statuses, mixed excluded. Issue #44 robustness cut: uses master_material literal-status source signals instead of is_required_inferred. required = at least one source book_status='required'; supplemental = at least one source book_status IN ('option','recommended'). Excludes (section,isbn) materials carrying both statuses (mixed/ambiguous), preserving the source-row conflict behavior at the canonical master_material grain. Same demeaning method as the primary same-ISBN question: subtract each ISBN's own overall median price_min, requiring >=10 total adoptions and at least 1 in each status. FINDING: essentially no premium survives this stricter literal cut — demeaned mean +$0.52 (required) vs +$0.35 (option/recommended), a ~$0.17 gap (median residual $0.00 for both) — versus a raw mean gap of ~$1.5 ($77.90 vs $76.38). The residual is a rounding-scale fraction of the ~$60 median price, plausibly channel-mix (required adoptions carry a rental option more often) rather than price discrimination. Read with the primary is_required_inferred question: no economically meaningful same-item required-vs-optional pricing effect at BMG scope. price_min = cheapest option (buy/rent, any condition/format) from master_material.
WITH adopt AS (
  SELECT CAST(isbn13 AS VARCHAR) AS isbn13,
    is_required_direct AS lit_required,
    price_min
  FROM master_material
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
    AND price_min IS NOT NULL
    AND (is_required_direct OR is_optional_or_recommended_direct)
    AND NOT (is_required_direct AND is_optional_or_recommended_direct)
),
isbn_stats AS (
  SELECT isbn13, MEDIAN(price_min) AS isbn_median
  FROM adopt
  GROUP BY isbn13
  HAVING COUNT(*) >= 10
    AND COUNT(*) FILTER (WHERE lit_required) > 0
    AND COUNT(*) FILTER (WHERE NOT lit_required) > 0
),
demeaned AS (
  SELECT a.isbn13, a.lit_required, a.price_min, a.price_min - m.isbn_median AS d_price
  FROM adopt a
  JOIN isbn_stats m ON a.isbn13 = m.isbn13
)
SELECT
  CASE WHEN lit_required THEN 'required (literal book_status)' ELSE 'option_or_recommended (literal book_status)' END AS status,
  COUNT(*) AS adoptions,
  COUNT(DISTINCT isbn13) AS distinct_isbns_matched,
  ROUND(MEDIAN(price_min), 2) AS raw_median_price,
  ROUND(AVG(price_min), 2) AS raw_mean_price,
  ROUND(MEDIAN(d_price), 2) AS median_vs_same_isbn_baseline,
  ROUND(AVG(d_price), 2) AS mean_vs_same_isbn_baseline
FROM demeaned
GROUP BY lit_required
ORDER BY lit_required DESC
