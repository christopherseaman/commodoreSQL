-- name: Fall 2025 Analysis — Set A: ≥1 required item (BMG grant scope)
-- display: table
-- description: BMG grant initial-analysis subset (issue #35), SET A. One row per Fall-2025 course section (period 2025-4) in the agreed 4-course-level × 6-teaching-sector scope. SET A has at least one required canonical-Use material: required_count > 0, where required combines is_required_inferred (#1) with is_course_material_use (#58). The full Master Section columns and audit fields are retained. 858,147 sections; disjoint from Set B and together exhaustive over the 2,653,161-section scope. Use scripts/export_fall2025_subsets.sh for the full Parquet.
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
