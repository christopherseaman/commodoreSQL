-- name: Master ISBN by Term
-- description: One row per period_sortable × ISBN13 for 2024+ nonblank, non-supply course materials (#55). Includes deterministic metadata plus conflict indicators, OER/IA, distinct institution/section/course counts, assigned-enrollment coverage and totals, all 18 wide-price-cell coverage counts, and institution-type section counts. Built from a distinct section × ISBN spine, so repeated catalog listings and rental terms do not multiply counts.
SELECT * FROM master_isbn
