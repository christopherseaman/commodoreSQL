-- name: Sections — CA Public, Fall 2025 (all columns)
-- display: table
-- description: One row per course section for California public institutions in Fall 2025 (period 2025-4), with every derived/enriched master_section column — institution enrichment (state, control, size, enrollment_2024 …), material/required/optional counts, OER/IA, coverage (has_isbn/has_formattype/isbn_count/classified_count), enrollment fill-potential flags, and cost. ~386k sections across 149 institutions.
SELECT *
FROM master_section
WHERE period_sortable = '2025-4'
  AND state   = 'CA'
  AND control = 'Public'
ORDER BY section_id
