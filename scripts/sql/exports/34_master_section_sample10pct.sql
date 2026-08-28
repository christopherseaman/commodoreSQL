-- Deterministic ~10% sample intersection of material-bearing master_section.
-- Membership is centralized over the complete section_enrollment population in
-- sample10_section_ids (MD5 prefix modulo 10, bucket zero), so every pipeline
-- stage uses the same sampled section keys. See #53.
-- Bare SELECT by export convention: run_sql.sh's process_export() (or the read-only
-- COPY runner) wraps this into output/34_master_section_sample10pct.csv.
SELECT ms.*
FROM master_section ms
JOIN sample10_section_ids sample USING (period_sortable, section_id);
