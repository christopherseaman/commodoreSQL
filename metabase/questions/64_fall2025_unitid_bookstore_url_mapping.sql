-- name: Fall 2025 — UNITID × Bookstore URL Mapping
-- display: table
-- description: One row per distinct nonblank UNITID/bookstore URL pair from all imported Fall 2025 BMG pricing rows. No required or inferred-required filter is applied. Multiple bookstore URLs for one UNITID remain separate; values are trimmed but otherwise source-preserved.

SELECT DISTINCT
    unit_id,
    TRIM(bookstore_url) AS bookstore_url
FROM pricing_historical
WHERE period_sortable = '2025-4'
  AND unit_id IS NOT NULL
  AND NULLIF(TRIM(bookstore_url), '') IS NOT NULL
ORDER BY unit_id, bookstore_url;
