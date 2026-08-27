-- Combined all-term Material Costs export.
-- One row per canonical-Use (period_sortable, section_id, isbn13) material,
-- including materials without a pricing match. Use export_cmm_masters.sh for
-- separate release-dated files by term. Bare SELECT by export convention.
SELECT *
FROM material_costs
ORDER BY period_sortable, section_id, isbn13;
