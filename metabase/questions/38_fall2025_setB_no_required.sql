-- name: Fall 2025 Analysis — Set B: no required item (BMG grant scope)
-- display: table
-- description: BMG grant initial-analysis subset (issue #35), SET B. One row per Fall-2025 course section (period 2025-4) from master_section, restricted to the agreed scope — course_level ∈ {Introductory/general undergrad, Intermediate undergrad, Non-degree credit, Uncategorized} AND the 6 real teaching sectors (IPEDS 1–6; blank/unknown sector, Administrative Unit, and all <2-year sectors excluded). SET B = sections with NO required item (required_count = 0, where required = filter_include / inferred is_required, issue #1) — includes sections whose only materials are optional AND sections with no book adoption entered. Carries every enriched master_section column (institution class, enrollment, seats, OER/IA, coverage flags, cost, is_supply/supply_count, enrollment_assigned/enrollment_source). Counts are post-#36 supply exclusion: 4,044 sections whose only required item was a supply are now here (their required_count fell to 0). 131,314 sections (was 127,270 pre-exclusion); partitions with Set A (≥1 required item) — disjoint and exhaustive over the 2,653,161-section scope. Saved re-runnable. NOTE: well within Metabase's download cap; full Parquet also via scripts/export_fall2025_subsets.sh.
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
