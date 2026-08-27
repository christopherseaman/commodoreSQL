-- Exact source/Master Section key-set reconciliation (#59).
--
-- Kept separate from export 38 so the 23.6M-key section state is released before
-- the distinct material-spine reconciliation starts. Every missing/extra count
-- must be zero and both key counts must match. Bare SELECT by export convention.
WITH source_keys AS MATERIALIZED (
    SELECT period_sortable, section_id
    FROM comprehensive_data
    WHERE period_date >= DATE '2024-01-01'
      AND period_sortable IS NOT NULL
      AND section_id IS NOT NULL
    GROUP BY period_sortable, section_id
),
key_presence AS (
    SELECT
        COALESCE(source.period_sortable, master.period_sortable) AS period_sortable,
        source.section_id AS source_section_id,
        master.section_id AS master_section_id
    FROM source_keys source
    FULL OUTER JOIN master_section master
      ON master.period_sortable = source.period_sortable
     AND master.section_id = source.section_id
)
SELECT
    period_sortable,
    COUNT(source_section_id) AS source_section_rows,
    COUNT(master_section_id) AS master_section_rows,
    COUNT(*) FILTER (WHERE source_section_id IS NOT NULL AND master_section_id IS NULL)
        AS missing_from_master_section,
    COUNT(*) FILTER (WHERE source_section_id IS NULL AND master_section_id IS NOT NULL)
        AS missing_from_source,
    COUNT(source_section_id) = COUNT(master_section_id)
      AND COUNT(*) FILTER (WHERE source_section_id IS NOT NULL AND master_section_id IS NULL) = 0
      AND COUNT(*) FILTER (WHERE source_section_id IS NULL AND master_section_id IS NOT NULL) = 0
        AS is_match
FROM key_presence
GROUP BY period_sortable
ORDER BY period_sortable;
