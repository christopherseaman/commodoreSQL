-- name: Fall 2025 Analysis — Set A: ≥1 required item (BMG grant scope)
-- display: table
-- description: Fall-2025 BMG-scope material-bearing sections with ≥1 inferred-required item. BMG grant initial-analysis subset (issue #35), SET A. One row per material-bearing Fall-2025 course section (period 2025-4) in the agreed 4-course-level × 6-teaching-sector scope. SET A has at least one required canonical master_material item: required_count > 0 under is_required_inferred (#1). All Master Section columns and retained-section audit fields are included. Set A is disjoint from Set B and together they exhaust the material-bearing Master Section scope; no-adoption/NoUse-only sections are outside this model. Use scripts/export_fall2025_subsets.sh for the full Parquet.
SELECT *
FROM master_section
WHERE period_sortable = '2025-4'
  AND course_level IN (
        'Introductory or general undergraduate',
        'Intermediate undergraduate',
        'Non-degree credit',
        'Uncategorized'
      )
  AND sector IN (
        'Public, 4-year or above',
        'Public, 2-year',
        'Private not-for-profit, 4-year or above',
        'Private not-for-profit, 2-year',
        'Private for-profit, 4-year or above',
        'Private for-profit, 2-year'
      )
  AND required_count > 0
ORDER BY section_id
