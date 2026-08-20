-- Combined all-term Master Institution export (#54).
-- One row per (period_sortable, unit_id); use export_cmm_masters.sh for separate
-- release-dated files by term.
SELECT * FROM master_institution ORDER BY period_sortable, unit_id;
