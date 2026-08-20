-- Deterministic ~10% sample of master_section (one row per section_id).
-- hash(section_id) % 10 = 0 partitions on the unique key: a uniform ~10% of rows that
-- is identical across runs and thread counts. (USING SAMPLE (bernoulli, seed) is not
-- reproducible here -- DuckDB's multi-threaded scan reorders the seeded draw per run.)
-- Bare SELECT by export convention: run_sql.sh's process_export() (or the read-only
-- COPY runner) wraps this into output/34_master_section_sample10pct.csv.
SELECT *
FROM master_section
WHERE hash(section_id) % 10 = 0;
