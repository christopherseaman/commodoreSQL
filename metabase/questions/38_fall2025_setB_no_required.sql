-- name: Fall 2025 Analysis — Set B: no required item (BMG grant scope)
-- display: table
-- description: BMG grant initial-analysis subset (issue #35), SET B. One row per Fall-2025 course section (period 2025-4) in the agreed 4-course-level × 6-teaching-sector scope. SET B has no required canonical-Use material: required_count = 0 under is_required_inferred (#1) plus is_course_material_use (#58). It includes optional-only, no-adoption, and NoUse-only sections while retaining the full Master Section audit/enrollment columns. 1,795,014 sections; disjoint from Set A and together exhaustive over the 2,653,161-section scope. Use scripts/export_fall2025_subsets.sh for the full Parquet (this set exceeds Metabase's download cap).
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
