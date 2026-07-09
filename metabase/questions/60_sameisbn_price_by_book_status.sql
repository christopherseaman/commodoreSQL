-- name: Fall 2025 — Same-ISBN Price by Literal book_status (required vs option/recommended)
-- display: table
-- description: Issue #44 robustness cut: uses the literal book_status field (from comprehensive_data) instead of is_required_inferred. required = book_status='required'; supplemental = book_status IN ('option','recommended'). Excludes (section,isbn) materials carrying both statuses (mixed/ambiguous). Same demeaning method as the primary same-ISBN question: subtract each ISBN's own overall median price_min, requiring >=10 total adoptions and at least 1 in each status. FINDING: essentially no premium survives this stricter literal cut — demeaned mean +$0.52 (required) vs +$0.35 (option/recommended), a ~$0.17 gap (median residual $0.00 for both) — versus a raw mean gap of ~$1.5 ($77.90 vs $76.38). The residual is a rounding-scale fraction of the ~$60 median price, plausibly channel-mix (required adoptions carry a rental option more often) rather than price discrimination. Read with the primary is_required_inferred question: no economically meaningful same-item required-vs-optional pricing effect at BMG scope. price_min = cheapest option (buy/rent, any condition/format) from pricing_wide.
WITH scope AS (
  SELECT section_id
  FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
),
lit_status AS (
  SELECT CAST(c."ISBN13" AS VARCHAR) AS isbn13, c.section_id,
    BOOL_OR(c.book_status = 'required') AS lit_required,
    BOOL_OR(c.book_status IN ('option','recommended')) AS lit_optional
  FROM comprehensive_data c
  JOIN scope s ON s.section_id = c.section_id
  WHERE c.period_sortable = '2025-4' AND c."ISBN13" IS NOT NULL
  GROUP BY c.section_id, c."ISBN13"
),
adopt AS (
  SELECT pw.isbn13, ls.lit_required, pw.price_min
  FROM pricing_wide pw
  JOIN lit_status ls ON ls.section_id = pw.section_id AND ls.isbn13 = pw.isbn13
  LEFT JOIN supply_isbn_classification sup ON sup.isbn13 = pw.isbn13
  WHERE pw.price_min IS NOT NULL
    AND sup.isbn13 IS NULL
    AND (ls.lit_required OR ls.lit_optional)
    AND NOT (ls.lit_required AND ls.lit_optional)
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
