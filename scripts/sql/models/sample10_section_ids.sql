-- Canonical deterministic 10% section sample membership (#53).
--
-- Sampling unit: section_id from the complete section_enrollment population.
-- Membership is intentionally independent of the material-bearing Master Section
-- release population, preserving the established full-universe count and hash
-- fingerprint. The first 64 bits of MD5(section_id), interpreted as an unsigned
-- integer, assign one of ten buckets; bucket 0 is retained. MD5 is used instead
-- of DuckDB hash() because the latter is not guaranteed stable across DuckDB
-- versions. This rule is versioned as md5-prefix64-mod10-v1.
WITH assigned AS (
    SELECT
        section_id,
        period_sortable,
        CAST('0x' || LEFT(md5(section_id), 16) AS UBIGINT) AS section_hash
    FROM section_enrollment
)
SELECT
    section_id,
    period_sortable,
    section_hash,
    CAST(section_hash % 10 AS UTINYINT) AS sample_bucket
FROM assigned
WHERE section_hash % 10 = 0;
