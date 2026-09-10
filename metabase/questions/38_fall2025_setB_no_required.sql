-- name: Fall 2025 Analysis — Set B: no required item (BMG grant scope)
-- display: table
-- description: Fall-2025 BMG-scope material-bearing sections with no inferred-required items; optional-only. BMG grant initial-analysis subset (issue #35), SET B. One row per material-bearing Fall-2025 course section (period 2025-4) in the agreed 4-course-level × 6-teaching-sector scope. SET B has no required canonical master_material item: required_count = 0 under is_required_inferred (#1), so it is optional-only. No-adoption and NoUse-only sections are outside Master Section. All retained-section audit/enrollment columns remain visible. Set B is disjoint from Set A and together they exhaust the material-bearing Master Section scope. Use scripts/export_fall2025_subsets.sh for the full Parquet.
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
  AND required_count = 0
ORDER BY section_id
