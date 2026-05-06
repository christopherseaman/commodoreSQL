-- name: DQ — Catalog → IPEDS Match
-- display: bar
-- description: Catalog rows split into IPEDS-matched / no-unit-id (Canadian, by design) / unit-id-not-in-IPEDS (closed/consolidated US schools).

SELECT metric_name, metric_value
FROM __data_quality_metrics
WHERE check_id = 'ipeds_match'
ORDER BY
    CASE metric_name
        WHEN 'total_rows'                   THEN 1
        WHEN 'no_unit_id_likely_canadian'   THEN 2
        WHEN 'unit_id_not_in_ipeds'         THEN 3
    END
