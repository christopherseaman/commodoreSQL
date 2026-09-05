-- Canonical Material Costs rows for the stable 10% section-cluster sample (#81).
-- sample10_section_ids owns membership; this table adds no second sampling path.
SELECT material.*
FROM material_costs material
JOIN sample10_section_ids sample USING (period_sortable, section_id);
