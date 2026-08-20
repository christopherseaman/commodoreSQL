-- Deterministic ~10% sample of master_section (one row per section_id).
-- Membership is centralized in sample10_section_ids (MD5 prefix modulo 10, bucket
-- zero) so every pipeline stage uses exactly the same sampled sections. See #53.
-- Bare SELECT by export convention: run_sql.sh's process_export() (or the read-only
-- COPY runner) wraps this into output/34_master_section_sample10pct.csv.
SELECT ms.*
FROM master_section ms
JOIN sample10_section_ids sample USING (section_id);
