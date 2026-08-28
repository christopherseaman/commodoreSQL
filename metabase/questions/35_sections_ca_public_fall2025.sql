-- name: Sections — CA Public, Fall 2025 (all columns)
-- display: table
-- description: One row per material-bearing course section for California public institutions in Fall 2025 (period 2025-4), with every derived/enriched master_section column: institution enrichment, canonical item counts, OER/IA, ISBN/FormatType coverage, enrollment fields, retained-section audit fields, and cost. No-adoption and NoUse-only sections remain upstream and are not included.
SELECT *
FROM master_section
WHERE period_sortable = '2025-4'
  AND state   = 'CA'
  AND control = 'Public'
ORDER BY section_id
