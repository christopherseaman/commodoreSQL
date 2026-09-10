-- name: Fall 2025 — Hypothesis: Same-Item Price by Class (course-mix vs price)
-- display: table
-- description: Fall-2025 BMG inferred-required priced Use adoptions; ISBNs with ≥10 adoptions. Isolates same-item price discrimination from course-mix. Required canonical Use adoptions come from master_material at one row per (period_sortable, section_id, isbn13), then price_min is demeaned by the SAME ISBN's median across adoptions (ISBNs with >=10 adoptions, so a cross-institution baseline exists). median_vs_market / mean_vs_market = dollars the class pays above (+) or below (-) the identical book's typical price; p25/p75 give the spread. FINDING: for the identical book, Public 2yr pays a mean +$1.63 above market vs Public 4yr's -$0.47 (medians $0.00 because most bookstores charge the same modal price; the effect is in the upper tail). This ~$2 same-item premium is small next to the ~$35/student class cost gap (see the enrollment-weighted cost question), so the class cost difference is overwhelmingly course-mix, not paying more for the same book. price_min is the cheapest available option (buy or rent, any condition/format) from master_material.
WITH adopt AS (
  SELECT CAST(isbn13 AS VARCHAR) AS isbn13, control,
    CASE level WHEN 'Four or more years' THEN '4yr' WHEN 'At least 2 but less than 4 years' THEN '2yr' END AS lvl,
    price_min
  FROM master_material
  WHERE period_sortable = '2025-4'
    AND course_level IN ('Introductory or general undergraduate','Intermediate undergraduate','Non-degree credit','Uncategorized')
    AND sector IN ('Public, 4-year or above','Public, 2-year','Private not-for-profit, 4-year or above','Private not-for-profit, 2-year','Private for-profit, 4-year or above','Private for-profit, 2-year')
    AND is_required_inferred
    AND price_min IS NOT NULL
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
