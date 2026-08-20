-- Combined all-term Master ISBN export (#55).
-- One row per (period_sortable, isbn13); use export_cmm_masters.sh for separate
-- release-dated files by term.
SELECT * FROM master_isbn ORDER BY period_sortable, isbn13;
