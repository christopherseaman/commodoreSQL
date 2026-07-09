-- name: Fall 2025 — Same-ISBN Price by Required Status (is_required_inferred)
-- display: table
-- description: Issue #44: is the same ISBN priced differently when required vs optional/supplemental? For every Fall 2025 BMG-scope (period_sortable=2025-4, 4 intro/intermediate course levels, 6 real teaching sectors) non-supply priced (section,isbn) adoption from pricing_wide, demeans price_min by that SAME ISBN's own overall median price_min. Included ISBNs need >=10 total adoptions AND at least 1 adoption in each required-status (14,665 ISBNs / 630,890 adoptions), so both a market baseline and a genuine within-item required-vs-optional contrast exist. required_status = is_required_inferred, the project's primary required flag. raw_median/mean_price show the unconditional gap (course-mix and book-identity effects included); median/mean_vs_same_isbn_baseline isolate the same-item effect by removing book identity. FINDING: raw median price is $10.75 higher for required ($63.99 vs $53.24, +20%), but once demeaned to the same book's own baseline the median residual is $0.00 for BOTH groups and the mean residual is identical to the cent ($1.07 vs $1.07) — no same-item pricing effect from required status survives. The raw gap is a course-mix effect (which books get flagged required), not price discrimination on an identical item, echoing the institution-level finding in the companion Same-Item Price by Class question. price_min is the cheapest available option (buy or rent, any condition/format) from pricing_wide. Confounds not controlled: institution/state/program mix within the pooled same-ISBN baseline — see GitHub issue #44 for deep-dive caveats.
WITH scope AS (
  SELECT section_id
  FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
),
adopt AS (
  SELECT pw.section_id, pw.isbn13, pw.is_required_inferred AS is_required, pw.price_min
  FROM scope s
  JOIN pricing_wide pw ON pw.section_id = s.section_id
  LEFT JOIN supply_isbn_classification sup ON sup.isbn13 = pw.isbn13
  WHERE pw.price_min IS NOT NULL
    AND sup.isbn13 IS NULL
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
