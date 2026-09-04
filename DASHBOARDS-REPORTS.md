---
notion-id: 3cbd9fdd-1a1a-80ee-884d-f4c7003aaf44
notion-url: https://app.notion.com/p/sqrlly/Dashboards-Reports-3cbd9fdd1a1a80ee884df4c7003aaf44
notion-sync: push
---

# Dashboards & Reports


## Reporting & analytical surfaces

### Course Materials Report

ID `13` · [`report`](metabase/dashboards/report.json) · Material-bearing sections under shared report filters.

| Card | ID | Scope |
|---|---:|---|
| Report — Section / OER / IA Overview | [`80`](metabase/questions/30_report_overview.sql) | Material-bearing sections/institutions under selected report filters. |
| Report — Materials Cost Summary | [`81`](metabase/questions/40_report_cost.sql) | Material-bearing sections under report filters; canonical required/optional costs. |

### Course Materials Cost

ID `9` · [`course_materials_cost`](metabase/dashboards/course_materials_cost.json) · Master Section required costs; buy-priced subset for owned.

| Card | ID | Scope |
|---|---:|---|
| Required Materials Cost by Subject (2024+) | [`75`](metabase/questions/24_cost_required_by_subject.sql) | Master Section required costs per section; buy-priced subset for owned. |
| Owned vs All-Options Cost by Course Level (2024+) | [`76`](metabase/questions/25_cost_owned_vs_all.sql) | Master Section required costs by level; buy-priced subset for owned. |

### OER/IA Adoption

ID `10` · [`oer_ia_adoption`](metabase/dashboards/oer_ia_adoption.json) · Canonical materials and material-bearing sections; card-specific denominators below.

| Card | ID | Scope |
|---|---:|---|
| OER/IA Rate Among Classified Materials (2024+) | [`82`](metabase/questions/31_oer_ia_rate_among_classified.sql) | Canonical Use items with FormatType; unclassified items excluded. |
| FormatType Classification Coverage Over Time (2024+) | [`83`](metabase/questions/32_formattype_coverage_over_time.sql) | All canonical material_costs items; fraction with FormatType. |
| OER/IA Section Adoption Over Time (2024+) | [`77`](metabase/questions/26_oer_ia_section_adoption.sql) | Material-bearing Master Section denominator; any canonical OER/IA item. |
| OER/IA Adoption Over Time (Filtered, 2024+) | [`55`](metabase/questions/05_filtered_oer_over_time.sql) | Canonical inferred-required items; enrollment counted once per section/OER/IA group. |

## BMG Fall 2025 analysis

### BMG · Fall 2025 Overview

ID `18` · [`bmg_overview`](metabase/dashboards/bmg_overview.json) · Fall-2025 BMG material-bearing sections; four course levels, six teaching sectors.

| Card | ID | Scope |
|---|---:|---|
| Fall 2025 — Section & Enrollment Counts by Institution Class x Set | [`128`](metabase/questions/39_fall2025_tally_counts_by_class.sql) | Fall-2025 BMG-scope material-bearing sections, by control/level/required-item set. |
| Fall 2025 — OER/IA Adoption & Material Coverage by Control x Level x Set | [`132`](metabase/questions/43_fall2025_tally_oer_ia_materials_coverage.sql) | Fall-2025 BMG-scope material-bearing sections; unweighted section shares/item counts. |
| Fall 2025 Analysis — Set A: ≥1 required item (BMG grant scope) | [`126`](metabase/questions/37_fall2025_setA_has_required.sql) | Fall-2025 BMG-scope material-bearing sections with ≥1 inferred-required item. |
| Fall 2025 Analysis — Set B: no required item (BMG grant scope) | [`127`](metabase/questions/38_fall2025_setB_no_required.sql) | Fall-2025 BMG-scope material-bearing sections with no inferred-required items; optional-only. |

### BMG · Enrollment Data Quality

ID `17` · [`bmg_enrollment_dq`](metabase/dashboards/bmg_enrollment_dq.json) · Fall-2025 BMG enrollment diagnostics, plus all-term material-bearing coverage.

| Card | ID | Scope |
|---|---:|---|
| Fall 2025 — Enrollment Assignment Summary (source mix + raw vs assigned) | [`134`](metabase/questions/45_fall2025_enrollment_assignment_summary.sql) | Fall-2025 BMG-scope material-bearing sections; raw/assigned enrollment by control/level/set. |
| Fall 2025 — Enrollment Missingness & Fill-Potential by Control × Level × Set | [`129`](metabase/questions/40_fall2025_tally_enrollment_fillpotential.sql) | Fall-2025 BMG-scope material-bearing sections; overlapping enrollment-fill signals. |
| Fall 2025 — Section Enrollment Distribution by Control x Level (present only) | [`130`](metabase/questions/41_fall2025_tally_enrollment_distribution.sql) | Fall-2025 BMG-scope material-bearing sections with present raw enrollment. |
| Coverage — Enrollment Fill-Potential (sections, 2024+) | [`91`](metabase/questions/33_coverage_enrollment_fill.sql) | Material-bearing Master Section denominator; overlapping enrollment-availability signals, not imputations. |
| Fall 2025 — Section Enrollment Assignment (persisted fill + provenance) | [`133`](metabase/questions/44_fall2025_enrollment_assigned.sql) | Fall-2025 BMG-scope material-bearing sections; persisted full-spine enrollment assignments. |

### BMG · Cost Hypothesis

ID `16` · [`bmg_cost_hypothesis`](metabase/dashboards/bmg_cost_hypothesis.json) · Fall-2025 BMG canonical materials; enrollment-weighted section costs and same-ISBN prices.

| Card | ID | Scope |
|---|---:|---|
| Fall 2025 — Hypothesis: Enrollment-Weighted Required Cost by Class | [`160`](metabase/questions/47_fall2025_hypothesis_enrollwt_cost.sql) | Fall-2025 BMG Set-A priced-required sections; enrollment-weighted cost midpoints. |
| Fall 2025 — Hypothesis: Same-Item Price by Class (course-mix vs price) | [`161`](metabase/questions/48_fall2025_hypothesis_sameitem_price.sql) | Fall-2025 BMG inferred-required priced Use adoptions; ISBNs with ≥10 adoptions. |
| Fall 2025 — Course-material cost by institution class (control x level x set) | [`131`](metabase/questions/42_fall2025_tally_cost_by_class.sql) | Fall-2025 BMG-scope material-bearing sections; section-weighted cost midpoints, not means. |
| Top-125 ISBN Cost Extract — Fall 2025 (institution × course × faculty) | [`125`](metabase/questions/36_top125_isbn_cost_extract.sql) | Fall-2025 canonical section/ISBN adoptions of 125 most-adopted ISBNs. |

## Coverage & lineage

### Data Coverage & Fill-Potential

ID `15` · [`data_coverage`](metabase/dashboards/data_coverage.json) · Material-bearing sections; enrollment recoverability and canonical-item classification coverage.

| Card | ID | Scope |
|---|---:|---|
| Coverage — Enrollment Fill-Potential (sections, 2024+) | [`91`](metabase/questions/33_coverage_enrollment_fill.sql) | Material-bearing Master Section denominator; overlapping enrollment-availability signals, not imputations. |
| Coverage — OER/IA Classifiability & ISBN (2024+) | [`92`](metabase/questions/34_coverage_oer_ia_isbn.sql) | Material-bearing Master Section denominator; canonical-item ISBN/FormatType coverage. |

### BMG Coverage & Scope

ID `19` · [`bmg_coverage_scope`](metabase/dashboards/bmg_coverage_scope.json) · Current snapshot: raw source, canonical-item, full-section, and retained-release denominators.

| Card | ID | Scope |
|---|---:|---|
| Coverage & Scope — Course Material Population by Term | [`173`](metabase/questions/65_coverage_course_material_population_by_term.sql) | Canonical course_materials term/section/ISBN groups, including NULL-ISBN audits. |
| Coverage & Scope — Course Material Exclusion Overlap | [`174`](metabase/questions/66_coverage_course_material_exclusion_overlap.sql) | Post-2024 canonical item groups; overlapping exclusion flags, not source rows. |
| Coverage & Scope — Canonical Material Classification by Term | [`175`](metabase/questions/67_coverage_course_material_classification_by_term.sql) | Canonical material_costs items per term/classification dimension, including unclassified. |
| Coverage & Scope — Complete Section Enrollment by Term | [`176`](metabase/questions/68_coverage_section_enrollment_by_term.sql) | Complete valid 2024+ section_enrollment spine; raw/assigned enrollment distinguished. |
| Coverage & Scope — Raw Pricing Options by Term | [`177`](metabase/questions/69_coverage_pricing_source_options_by_term.sql) | All raw pricing observations by term/option/condition/format; no Use/required filter. |
| Coverage & Scope — Canonical Use Pricing by Term | [`178`](metabase/questions/70_coverage_canonical_pricing_by_term.sql) | Canonical material_costs item denominator; exact matches versus valid prices. |
| Coverage & Scope — Canonical Retained Sections by Institution Profile | [`179`](metabase/questions/71_coverage_canonical_by_institution.sql) | Institution-profile rollups; percentages divide by retained canonical sections. |
| Coverage & Scope — Canonical Price Cells by Term | [`180`](metabase/questions/72_coverage_canonical_price_cells_by_term.sql) | Canonical term/ISBN rollups; section-item occurrences denominator, overlapping price cells. |
| FormatType Classification Coverage Over Time (2024+) | [`83`](metabase/questions/32_formattype_coverage_over_time.sql) | All canonical material_costs items; fraction with FormatType. |
| OER/IA Rate Among Classified Materials (2024+) | [`82`](metabase/questions/31_oer_ia_rate_among_classified.sql) | Canonical Use items with FormatType; unclassified items excluded. |
| FormatType Coverage by Supply Status (2024+) | [`162`](metabase/questions/57_formattype_coverage_by_supply.sql) | Raw 2024+ ISBN-bearing catalog rows, by supply status; no Use filter. |
| Coverage — Enrollment Fill-Potential (sections, 2024+) | [`91`](metabase/questions/33_coverage_enrollment_fill.sql) | Material-bearing Master Section denominator; overlapping enrollment-availability signals, not imputations. |
| DQ — Pricing → Catalog Match Rate by Period | [`60`](metabase/questions/10_dq_pricing_match_by_period.sql) | All raw pricing rows by term; exact catalog section/ISBN match rate. |
| DQ — Canonical Required Material format_count Distribution | [`78`](metabase/questions/27_dq_pricing_format_count_distribution_filtered.sql) | Canonical inferred-required section/ISBN items with exact pricing matches. format_count distribution for canonical Course Materials Use items that are inferred-required and have an exact pricing match. |

### Data Lineage — by School

ID `14` · [`data_lineage`](metabase/dashboards/data_lineage.json) · Selected-school teaching path; not complete executable lineage.

| Card | ID | Scope |
|---|---:|---|
| Lineage 1 — Raw Catalog (BMG course materials) | [`84`](metabase/questions/50_lineage_catalog.sql) | Raw 2024+ catalog rows for selected school; no Use exclusions. |
| Lineage 2 — Merged (catalog × IPEDS × OER/IA) | [`85`](metabase/questions/51_lineage_merged.sql) | All 2024+ comprehensive_data rows for selected school; no Use exclusions. |
| Lineage 3 — Raw Cost (BMG pricing) | [`86`](metabase/questions/52_lineage_pricing.sql) | All raw pricing option rows for selected school. |
| Lineage 4 — Pricing Wide (pivoted) | [`87`](metabase/questions/53_lineage_pricing_wide.sql) | Pricing-wide section/ISBN pairs for selected school. |
| Lineage 5 — Section Cost | [`88`](metabase/questions/54_lineage_section_cost.sql) | Section-cost rows for selected school; all-options and buy-only. |
| Lineage 6 — Master Section (wide record) | [`89`](metabase/questions/55_lineage_master_section.sql) | Material-bearing Master Section rows for selected school. |
| Lineage 7 — Master Course (rollup) | [`90`](metabase/questions/56_lineage_master_course.sql) | Master Course rollups across material-bearing sections for selected school. |

## Data quality dashboards

### Required Inference — Raw Data Quality (2024+)

ID `6` · [`filter_include_quality`](metabase/dashboards/filter_include_quality.json) · Raw inferred-required diagnostics alongside canonical required-item FormatType coverage.

| Card | ID | Scope |
|---|---:|---|
| Raw Inferred-Required vs Not-Inferred Counts by Course Level and Period | [`49`](metabase/questions/01_filter_include_counts.sql) | Raw 2024+ catalog rows, by inferred-required flag, level, and term. |
| FormatType Coverage by Course Level and Period (Filtered) | [`50`](metabase/questions/02_formattype_coverage.sql) | Canonical inferred-required items, by FormatType coverage, level, and term. |
| Sections with Not-Inferred-Required Rows by Course Level and Period (2024+) | [`51`](metabase/questions/03_sections_no_materials.sql) | Raw 2024+ sections containing not-inferred-required rows; not material-free sections. |

### OER/IA + Status (Filtered, 2024+)

ID `5` · [`oer_ia_status_filtered`](metabase/dashboards/oer_ia_status_filtered.json) · Canonical inferred-required items, 2024+; FormatType/OER/IA/status cross-tabs.

| Card | ID | Scope |
|---|---:|---|
| FormatType x OER x IA x Status (Filtered, 2024+) | [`54`](metabase/questions/04_filtered_formattype_status.sql) | Canonical inferred-required items; enrollment counted once per section/group. |
| OER/IA Adoption Over Time (Filtered, 2024+) | [`55`](metabase/questions/05_filtered_oer_over_time.sql) | Canonical inferred-required items; enrollment counted once per section/OER/IA group. |

### Data Quality — Catalog

ID `7` · [`data_quality_catalog`](metabase/dashboards/data_quality_catalog.json) · Inferred-required catalog rows, 2024+; not canonical Use.

| Card | ID | Scope |
|---|---:|---|
| DQ — Catalog → IPEDS Match | [`63`](metabase/questions/13_dq_catalog_ipeds_match.sql) | Inferred-required 2024+ catalog rows, by IPEDS match status. |
| DQ — Top Schools Missing from IPEDS | [`64`](metabase/questions/14_dq_catalog_top_unmatched_ipeds.sql) | Inferred-required 2024+ catalog rows at US institutions missing IPEDS. |
| DQ — Top Schools by NULL ISBN | [`65`](metabase/questions/15_dq_catalog_top_null_isbn.sql) | Inferred-required 2024+ catalog rows; NULL-ISBN percentage per school. |
| DQ — Null ISBN Breakdown by Placeholder Type | [`74`](metabase/questions/23_dq_null_isbn_breakdown.sql) | Inferred-required 2024+ catalog NULL-ISBN rows, by school/placeholder. |
| DQ — Enrollment Sanity | [`66`](metabase/questions/16_dq_catalog_enrollment_sanity.sql) | Inferred-required 2024+ catalog rows with enrollment/seat anomalies. |
| DQ — Email Validity | [`67`](metabase/questions/17_dq_catalog_email_validity.sql) | Inferred-required 2024+ catalog rows with email anomalies. |

### Data Quality — Pricing

ID `8` · [`data_quality_pricing`](metabase/dashboards/data_quality_pricing.json) · Raw pricing pipeline; deduplication, validity, and catalog matching.

| Card | ID | Scope |
|---|---:|---|
| DQ — Critical Metrics (should be 0) | [`68`](metabase/questions/18_dq_critical_should_be_zero.sql) | Pricing grain/pivot/price-bound and catalog classification regression checks. |
| DQ — Pricing Dedupe Stages | [`56`](metabase/questions/06_dq_pricing_dedupe_stages.sql) | Raw pricing rows through successive deduplication stages. |
| DQ — Pricing Price Outliers | [`57`](metabase/questions/07_dq_pricing_price_outliers.sql) | Raw pricing rows at zero, sentinel, and outlier boundaries. |
| DQ — Pricing Buy/Rental Discipline | [`58`](metabase/questions/08_dq_pricing_buy_rental_discipline.sql) | Raw pricing rows with option/rental-term inconsistencies. |
| DQ — Digital Rental Days Consistency | [`59`](metabase/questions/09_dq_pricing_digital_rental_days.sql) | Raw digital rentals grouped by section/ISBN; mixed NULL terms flagged. |
| DQ — Pricing → Catalog Match Rate by Period | [`60`](metabase/questions/10_dq_pricing_match_by_period.sql) | All raw pricing rows by term; exact catalog section/ISBN match rate. |
| DQ — Pricing Wide format_count Distribution | [`61`](metabase/questions/11_dq_pricing_format_count_distribution.sql) | Pricing-wide pairs by offered buy/rental tuple count, regardless of price validity. |
| DQ — Top Unmatched Pricing Section Cohorts | [`62`](metabase/questions/12_dq_pricing_top_unmatched_sections.sql) | All raw pricing sections lacking exact catalog matches, by institution/term. |
| DQ — Raw Physical Rental Rows per (Section × Item) | [`72`](metabase/questions/21_dq_rental_rows_per_pair_physical.sql) | All raw physical rentals, counting rows per section/ISBN pair. |
| DQ — Raw Digital Rental Rows per (Section × Item) | [`73`](metabase/questions/22_dq_rental_rows_per_pair_digital.sql) | All raw digital rentals, counting rows per section/ISBN pair. |
| DQ — Raw Digital Rental Period Length Distribution | [`70`](metabase/questions/20_dq_rental_period_length_distribution.sql) | All raw digital rental rows with non-NULL rental_days. |
| DQ — Rental Row-Shape Distribution per (Section × Item) | [`69`](metabase/questions/19_dq_rental_rows_per_section_item.sql) | All raw rental section/ISBN pairs, by physical/digital row-count shape. |

### Data Quality — Raw Pricing + Canonical Required Materials

ID `11` · [`data_quality_pricing_filtered`](metabase/dashboards/data_quality_pricing_filtered.json) · All raw pricing; matched canonical inferred-required items only for Q27.

| Card | ID | Scope |
|---|---:|---|
| DQ — Critical Metrics (should be 0) | [`68`](metabase/questions/18_dq_critical_should_be_zero.sql) | Pricing grain/pivot/price-bound and catalog classification regression checks. |
| DQ — Pricing Dedupe Stages | [`56`](metabase/questions/06_dq_pricing_dedupe_stages.sql) | Raw pricing rows through successive deduplication stages. |
| DQ — Pricing Price Outliers | [`57`](metabase/questions/07_dq_pricing_price_outliers.sql) | Raw pricing rows at zero, sentinel, and outlier boundaries. |
| DQ — Pricing Buy/Rental Discipline | [`58`](metabase/questions/08_dq_pricing_buy_rental_discipline.sql) | Raw pricing rows with option/rental-term inconsistencies. |
| DQ — Digital Rental Days Consistency | [`59`](metabase/questions/09_dq_pricing_digital_rental_days.sql) | Raw digital rentals grouped by section/ISBN; mixed NULL terms flagged. |
| DQ — Pricing → Catalog Match Rate by Period | [`60`](metabase/questions/10_dq_pricing_match_by_period.sql) | All raw pricing rows by term; exact catalog section/ISBN match rate. |
| DQ — Canonical Required Material format_count Distribution | [`78`](metabase/questions/27_dq_pricing_format_count_distribution_filtered.sql) | Canonical inferred-required section/ISBN items with exact pricing matches. format_count distribution for canonical Course Materials Use items that are inferred-required and have an exact pricing match. |
| DQ — Top Unmatched Pricing Section Cohorts | [`62`](metabase/questions/12_dq_pricing_top_unmatched_sections.sql) | All raw pricing sections lacking exact catalog matches, by institution/term. |
| DQ — Raw Physical Rental Rows per (Section × Item) | [`72`](metabase/questions/21_dq_rental_rows_per_pair_physical.sql) | All raw physical rentals, counting rows per section/ISBN pair. |
| DQ — Raw Digital Rental Rows per (Section × Item) | [`73`](metabase/questions/22_dq_rental_rows_per_pair_digital.sql) | All raw digital rentals, counting rows per section/ISBN pair. |
| DQ — Raw Digital Rental Period Length Distribution | [`70`](metabase/questions/20_dq_rental_period_length_distribution.sql) | All raw digital rental rows with non-NULL rental_days. |
| DQ — Rental Row-Shape Distribution per (Section × Item) | [`69`](metabase/questions/19_dq_rental_rows_per_section_item.sql) | All raw rental section/ISBN pairs, by physical/digital row-count shape. |

## Standalone cards

### Fall 2025 extracts and operational audits

| Card | ID | Scope |
|---|---:|---|
| Sections — CA Public, Fall 2025 (all columns) | [`93`](metabase/questions/35_sections_ca_public_fall2025.sql) | California-public Fall-2025 material-bearing sections. |
| Master ISBN dataset — Fall 2025 (material-listing distribution) | [`157`](metabase/questions/46_master_isbn_fall2025.sql) | All raw Fall-2025 catalog listing combinations, including NULL ISBNs. |
| Top 100 Non-Supply ISBNs Missing FormatType (Fall 2025) | [`164`](metabase/questions/58_top100_nonsupply_missing_formattype.sql) | Raw Fall-2025 non-supply ISBNs missing FormatType; top-100 section-adoption counts. |
| Fall 2025 — Sections with no price choice, by institution class (#46) | [`169`](metabase/questions/63_no_price_choice_by_class.sql) | Fall-2025 BMG material-bearing section denominator; required price_min=price_max tests. |
| Fall 2025 — UNITID × Bookstore URL Mapping | [`172`](metabase/questions/64_fall2025_unitid_bookstore_url_mapping.sql) | All raw Fall-2025 pricing; distinct nonblank institution/bookstore-URL pairs. |

### Same-item pricing analyses

| Card | ID | Scope |
|---|---:|---|
| Fall 2025 — Same-ISBN Price by Required Status (is_required_inferred) | [`165`](metabase/questions/59_sameisbn_price_by_required_status.sql) | Fall-2025 BMG priced Use adoptions; ≥10/ISBN, both inferred-required statuses. |
| Fall 2025 — Same-ISBN Price by Literal book_status (required vs option/recommended) | [`166`](metabase/questions/60_sameisbn_price_by_book_status.sql) | Fall-2025 BMG priced Use adoptions; ≥10/ISBN, both literal statuses, mixed excluded. |

### ISBN identity and title-cluster review

| Card | ID | Scope |
|---|---:|---|
| Master ISBN — listing variability (Fall 2025) | [`167`](metabase/questions/61_master_isbn_variability.sql) | All raw Fall-2025 ISBN-bearing catalog rows; no Use/supply filter. |
| Master ISBN -- title-cluster blessed-ISBN13 candidates (Fall 2025) | [`168`](metabase/questions/62_master_isbn_title_cluster_candidates.sql) | Raw Fall-2025 nonblank title clusters with multiple ISBNs; review-only. |

## Models

| Model | ID | Scope |
|---|---:|---|
| Master Institution by Term | [`170`](metabase/models/master_institution.sql) | Material-bearing institutions, one row per term/institution, 2024+; unknown bucket retained. |
| Master ISBN by Term | [`171`](metabase/models/master_isbn.sql) | Canonical Use population, one row per term/ISBN, 2024+. |
| Master Section | [`158`](metabase/models/master_section.sql) | One row per canonical material-bearing section, 2024+. |
| Master Section — US Intro/Intermediate, Fall 2025 (BMG scope) | [`159`](metabase/models/master_section_us_intro_fall2025.sql) | Fall-2025 required intro/intermediate sections; nonblank/non-Canada state proxy, not validated US. |

## Coverage checks

- Dashboards: 14; questions: 70; models: 4
- Dashboard card placements: 79; unique dashboard-used questions: 61; standalone questions: 9
IDs link to sources; placements repeat.

## Regeneration

`python3 scripts/generate_dashboards_reports.py` prints this inventory; `--check` detects drift.
