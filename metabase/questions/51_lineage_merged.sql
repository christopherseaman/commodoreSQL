-- name: Lineage 2 — Merged (catalog × IPEDS × OER/IA)
-- display: table
-- description: All 2024+ comprehensive_data rows for selected school; no Use exclusions. Raw/all comprehensive_data records dated 2024+ — catalog + IPEDS + OER/IA + is_required_inferred + coverage flags. Use, NoUse, Canada, NULL-ISBN, and supply rows remain included; this is lineage/DQ context, not a canonical-material denominator. Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter. The LIMIT 200 is display-only.
SELECT *
FROM comprehensive_data
WHERE period_date >= '2024-01-01'
  [[ AND CAST(unit_id AS VARCHAR) = {{unit_id}} ]]
ORDER BY section_id, ISBN13
LIMIT 200
