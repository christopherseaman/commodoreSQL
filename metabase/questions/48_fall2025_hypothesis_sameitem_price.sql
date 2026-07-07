-- name: Fall 2025 — Hypothesis: Same-Item Price by Class (course-mix vs price)
-- display: table
-- description: Isolates same-item price discrimination from course-mix. For every required, non-supply, priced section-adoption in the BMG scope, demeans the price by the SAME ISBN's median cheapest price (price_min) across all its adoptions (ISBNs with >=10 adoptions, so a cross-institution baseline exists). median_vs_market / mean_vs_market = dollars the class pays above (+) or below (-) the identical book's typical price; p25/p75 give the spread. This removes both course-mix AND book-identity confounds, leaving only the institution effect. FINDING: for the identical book, Public 2yr pays a mean +$1.62 above market vs Public 4yr's -$0.47 (medians ~0 because most bookstores charge the same modal price; the effect is in the upper tail). This ~$2 same-item premium is small next to the ~$35/student class cost gap (see the enrollment-weighted cost question) — so the class cost difference is overwhelmingly course-mix (which/how many books), NOT paying more for the same book. price_min is the cheapest available option (buy or rent, any condition/format) from pricing_wide.
WITH scope AS (
  SELECT section_id, control,
    CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
    enrollment_assigned
  FROM master_section
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
),
adopt AS (
  SELECT c."ISBN13" AS isbn13, s.control, s.lvl, pw.price_min
  FROM scope s
  JOIN comprehensive_data c
    ON c.section_id = s.section_id AND c.period_sortable = '2025-4'
    AND c.filter_include AND NOT c.is_supply
  JOIN pricing_wide pw ON pw.section_id = c.section_id AND pw.isbn13 = c."ISBN13"
  WHERE pw.price_min IS NOT NULL
),
isbn_med AS (
  SELECT isbn13, MEDIAN(price_min) AS m FROM adopt GROUP BY isbn13 HAVING COUNT(*) >= 10
),
demeaned AS (
  SELECT a.control, a.lvl, a.price_min - m.m AS d_price
  FROM adopt a JOIN isbn_med m ON a.isbn13 = m.isbn13
)
SELECT
  control,
  lvl AS level,
  COUNT(*) AS adoptions,
  ROUND(MEDIAN(d_price), 2) AS median_vs_market,
  ROUND(AVG(d_price), 2) AS mean_vs_market,
  ROUND(quantile_cont(d_price, 0.25), 2) AS p25,
  ROUND(quantile_cont(d_price, 0.75), 2) AS p75
FROM demeaned
GROUP BY control, lvl
ORDER BY mean_vs_market DESC
