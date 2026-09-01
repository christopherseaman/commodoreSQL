---
notion-id: 3cbd9fdd-1a1a-80ee-884d-f4c7003aaf44
notion-url: https://app.notion.com/p/sqrlly/Dashboards-Reports-3cbd9fdd1a1a80ee884df4c7003aaf44
notion-sync: push
---

# Dashboards & Reports

This is the authoritative inventory of repository-defined Metabase dashboards, cards, and models. Dashboard order is conceptual: reporting surfaces, BMG Fall 2025 analysis, coverage/lineage, data quality, then standalone analytical extracts and review diagnostics. Card order follows each dashboard JSON layout. Scope descriptions come from SQL frontmatter; this document makes no claims about live query results.

## Reporting & analytical surfaces

### Course Materials Report

ID `13` · [`report`](metabase/dashboards/report.json) · Parameterized report surface (#18). 13 dashboard filters (time, geography, institution, course, material) auto-mapped to every card. Overview = sections/OER/IA; Cost = required/optional/owned cost over the selected sections.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Report — Section / OER / IA Overview | `80` | [`30_report_overview`](metabase/questions/30_report_overview.sql) | Material-bearing sections and institutions, with canonical-Use OER/IA adoption, over the selected filters. |
| Report — Materials Cost Summary | `81` | [`40_report_cost`](metabase/questions/40_report_cost.sql) | Canonical-Use required/optional materials cost over material-bearing sections (per-section, 2024+). |

### Course Materials Cost

ID `9` · [`course_materials_cost`](metabase/dashboards/course_materials_cost.json) · Required-material cost by subject and level; owned (buy-only) vs all-options. Section grain, 2024+.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Required Materials Cost by Subject (2024+) | `75` | [`24_cost_required_by_subject`](metabase/questions/24_cost_required_by_subject.sql) | Average required-material cost per section by course subject, with owned (buy-only) comparison and price coverage. |
| Owned vs All-Options Cost by Course Level (2024+) | `76` | [`25_cost_owned_vs_all`](metabase/questions/25_cost_owned_vs_all.sql) | Required-material cost — all options (incl. rental) vs owned (buy-only) — by course level. |

### OER/IA Adoption

ID `10` · [`oer_ia_adoption`](metabase/dashboards/oer_ia_adoption.json) · OER / Inclusive-Access adoption. Cards 31/32 use canonical Course Materials Use rows: card 31's OER/IA rate denominator is classified Use materials (FormatType present), while card 32's coverage denominator is all Use material rows. Card 26 divides section adoption by material-bearing master_section rows; card 05 counts inferred-required Use rows. Read absolute IA counts alongside FormatType coverage.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| OER/IA Rate Among Classified Materials (2024+) | `82` | [`31_oer_ia_rate_among_classified`](metabase/questions/31_oer_ia_rate_among_classified.sql) | OER/IA as a share of canonical Use materials that HAVE a FormatType classification (denominator excludes unclassified). |
| FormatType Classification Coverage Over Time (2024+) | `83` | [`32_formattype_coverage_over_time`](metabase/questions/32_formattype_coverage_over_time.sql) | Share of canonical deduplicated material_costs items that carry a FormatType (and are thus OER/IA-classifiable). |
| OER/IA Section Adoption Over Time (2024+) | `77` | [`26_oer_ia_section_adoption`](metabase/questions/26_oer_ia_section_adoption.sql) | Share of material-bearing course sections with any OER / any Inclusive-Access canonical item, by period (from master_section). |
| OER/IA Adoption Over Time (Filtered, 2024+) | `55` | [`05_filtered_oer_over_time`](metabase/questions/05_filtered_oer_over_time.sql) | OER and IA item counts by period over canonical inferred-required material_costs rows. total_enrollments counts each section once within its displayed OER/IA group. |

## BMG Fall 2025 analysis

### BMG · Fall 2025 Overview

ID `18` · [`bmg_overview`](metabase/dashboards/bmg_overview.json) · The Fall 2025 grant-analysis landscape over material-bearing Master Section rows: section + enrollment counts and OER/IA + material coverage by institution class (control x 2yr/4yr) x A/B set. Set A has >=1 required canonical material_costs item and Set B is optional-only. Scope: 4 undergrad course levels x 6 real teaching sectors. Enrollment assignments originate from the complete section_enrollment population.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Fall 2025 — Section & Enrollment Counts by Institution Class x Set | `128` | [`39_fall2025_tally_counts_by_class`](metabase/questions/39_fall2025_tally_counts_by_class.sql) | Headline size table for the material-bearing Fall-2025 BMG grant scope. |
| Fall 2025 — OER/IA Adoption & Material Coverage by Control x Level x Set | `132` | [`43_fall2025_tally_oer_ia_materials_coverage`](metabase/questions/43_fall2025_tally_oer_ia_materials_coverage.sql) | Per-section tally over material-bearing Master Section rows in the Fall-2025 BMG scope, showing OER/IA adoption, material load, and ISBN/FormatType coverage by institution control × level × A/B set. |
| Fall 2025 Analysis — Set A: ≥1 required item (BMG grant scope) | `126` | [`37_fall2025_setA_has_required`](metabase/questions/37_fall2025_setA_has_required.sql) | BMG grant initial-analysis subset (issue #35), SET A. |
| Fall 2025 Analysis — Set B: no required item (BMG grant scope) | `127` | [`38_fall2025_setB_no_required`](metabase/questions/38_fall2025_setB_no_required.sql) | BMG grant initial-analysis subset (issue #35), SET B. |

### BMG · Enrollment Data Quality

ID `17` · [`bmg_enrollment_dq`](metabase/dashboards/bmg_enrollment_dq.json) · Missing enrollment and its assignment provenance among material-bearing Master Section rows. Summary: fill-source mix (own -> own_seats -> sibling_enroll -> sibling_seats -> class_median -> level_median), raw versus assigned totals, and imputed share by class and A/B set. The assignment values and medians originate from the complete section_enrollment population, while these cards display the narrowed release population. Gate enrollment-weighted results on enrollment_source; seats_taken=9999 is an invalid sentinel.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Fall 2025 — Enrollment Assignment Summary (source mix + raw vs assigned) | `134` | [`45_fall2025_enrollment_assignment_summary`](metabase/questions/45_fall2025_enrollment_assignment_summary.sql) | Companion to question 44, aggregating persisted enrollment fill (#32) over material-bearing Master Section rows. |
| Fall 2025 — Enrollment Missingness & Fill-Potential by Control × Level × Set | `129` | [`40_fall2025_tally_enrollment_fillpotential`](metabase/questions/40_fall2025_tally_enrollment_fillpotential.sql) | Per-section tally over the material-bearing Fall-2025 Master Section BMG scope, showing enrollment coverage and fill-potential by institution control × level × A/B set (A = >=1 required item, B = optional-only). |
| Fall 2025 — Section Enrollment Distribution by Control x Level (present only) | `130` | [`41_fall2025_tally_enrollment_distribution`](metabase/questions/41_fall2025_tally_enrollment_distribution.sql) | Distribution of present raw per-section enrollment among material-bearing Fall-2025 Master Section rows in the BMG grant scope, grouped by institution control × level. sections_n_present excludes NULL enrollment; enrollment_mean is the arithmetic mean and percentiles use quantile_cont. |
| Coverage — Enrollment Fill-Potential (sections, 2024+) | `91` | [`33_coverage_enrollment_fill`](metabase/questions/33_coverage_enrollment_fill.sql) | Enrollment coverage among material-bearing Master Section rows. |
| Fall 2025 — Section Enrollment Assignment (persisted fill + provenance) | `133` | [`44_fall2025_enrollment_assigned`](metabase/questions/44_fall2025_enrollment_assigned.sql) | Per-section enrollment fill for the material-bearing BMG grant scope (Fall 2025), reading persisted enrollment_assigned/enrollment_source values joined from the complete section_enrollment source (#32). |

### BMG · Cost Hypothesis

ID `16` · [`bmg_cost_hypothesis`](metabase/dashboards/bmg_cost_hypothesis.json) · Tests whether 2-year (esp. public) students pay more for course materials. Enrollment-weighted cost (top): Public 2yr students face ~$149/student in required materials vs ~$114 for Public 4yr (+31%), robust to enrollment imputation (own-only) and cost outliers (winsorized). Same-item price (second): for the IDENTICAL book, Public 2yr pays only ~$2 above market — so the class gap is overwhelmingly course-mix (which/how many books), NOT same-item price discrimination. Section-level cost medians by class (third) and the Top-125 same-item extract (bottom) support the read. All *_cost columns are (min+max)/2 summaries, NOT arithmetic means; cost aggregates use the canonical #58 Course Materials Use population; enrollment_assigned (#32) drives the weighting.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Fall 2025 — Hypothesis: Enrollment-Weighted Required Cost by Class | `160` | [`47_fall2025_hypothesis_enrollwt_cost`](metabase/questions/47_fall2025_hypothesis_enrollwt_cost.sql) | Tests whether 2-year (esp. public) students face higher required-material costs. |
| Fall 2025 — Hypothesis: Same-Item Price by Class (course-mix vs price) | `161` | [`48_fall2025_hypothesis_sameitem_price`](metabase/questions/48_fall2025_hypothesis_sameitem_price.sql) | Isolates same-item price discrimination from course-mix. |
| Fall 2025 — Course-material cost by institution class (control x level x set) | `131` | [`42_fall2025_tally_cost_by_class`](metabase/questions/42_fall2025_tally_cost_by_class.sql) | Per-section course-material cost summaries for material-bearing Fall-2025 Master Section rows in the BMG scope, broken out by institution control × level × A/B set. |
| Top-125 ISBN Cost Extract — Fall 2025 (institution × course × faculty) | `125` | [`36_top125_isbn_cost_extract`](metabase/questions/36_top125_isbn_cost_extract.sql) | One row per canonical Use Fall-2025 (period 2025-4) section-adoption of the 125 most common ISBNs (ranked by distinct sections), read from material_costs at its canonical (period_sortable, section_id, isbn13) grain. |

## Coverage & lineage

### Data Coverage & Fill-Potential

ID `15` · [`data_coverage`](metabase/dashboards/data_coverage.json) · Where values are missing and how much could be recovered. Enrollment is NOT imputed — the fill-potential flags only quantify recoverability (~28% of missing enrollment is fillable from some signal). OER/IA missingness is ISBN-structural: internal inference fills 0, so raising coverage needs an external ISBN→OER/IA source.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Coverage — Enrollment Fill-Potential (sections, 2024+) | `91` | [`33_coverage_enrollment_fill`](metabase/questions/33_coverage_enrollment_fill.sql) | Enrollment coverage among material-bearing Master Section rows. |
| Coverage — OER/IA Classifiability & ISBN (2024+) | `92` | [`34_coverage_oer_ia_isbn`](metabase/questions/34_coverage_oer_ia_isbn.sql) | ISBN and OER/IA-classification coverage among canonical material_costs items rolled into material-bearing Master Section rows. |

### BMG Coverage & Scope

ID `19` · [`bmg_coverage_scope`](metabase/dashboards/bmg_coverage_scope.json) · Current snapshot coverage map from BMG source observations through canonical Course Materials, enrollment, pricing, and release populations. The Term filter defaults to the current snapshot term (2025-4) and applies to all 14 cards; card descriptions identify each source or canonical grain and denominator.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Coverage & Scope — Course Material Population by Term | `173` | [`65_coverage_course_material_population_by_term`](metabase/questions/65_coverage_course_material_population_by_term.sql) | Current-snapshot coverage from the canonical course_materials item-group spine (one period × section × ISBN, including one NULL-ISBN audit group per section), while reconstructed_source_rows sums source_row_count back to the enriched BMG source-row grain. |
| Coverage & Scope — Course Material Exclusion Overlap | `174` | [`66_coverage_course_material_exclusion_overlap`](metabase/questions/66_coverage_course_material_exclusion_overlap.sql) | Current-snapshot overlap audit at the canonical course_materials_post_2024 item-group grain (one period × section × ISBN audit group). |
| Coverage & Scope — Canonical Material Classification by Term | `175` | [`67_coverage_course_material_classification_by_term`](metabase/questions/67_coverage_course_material_classification_by_term.sql) | Current-snapshot classification frequencies over canonical material_costs Use items (one period × section × ISBN). |
| Coverage & Scope — Complete Section Enrollment by Term | `176` | [`68_coverage_section_enrollment_by_term`](metabase/questions/68_coverage_section_enrollment_by_term.sql) | Current-snapshot enrollment coverage over the complete valid 2024+ section_enrollment spine, where section_count is the full section denominator and raw versus assigned enrollment remain distinct. |
| Coverage & Scope — Raw Pricing Options by Term | `177` | [`69_coverage_pricing_source_options_by_term`](metabase/questions/69_coverage_pricing_source_options_by_term.sql) | Current-snapshot source coverage at the BMG-owned pricing_historical observation grain, grouped by term × source option × condition × format with no canonical Use, required, or inferred-required filter. valid_price means price < 9999, so zero is valid; key counts use distinct raw section × ISBN pairs. |
| Coverage & Scope — Canonical Use Pricing by Term | `178` | [`70_coverage_canonical_pricing_by_term`](metabase/questions/70_coverage_canonical_pricing_by_term.sql) | Current-snapshot pricing and classification coverage over canonical material_costs Use items (one period × section × ISBN). inferred_required_item_count uses catalog is_required_inferred; inferred_optional_item_count is its complement. item_count is the percentage denominator; section/course/institution/ISBN columns are distinct canonical denominators. has_pricing_match records exact source-key presence, while valid_price_item_count requires non-NULL price_min after the <9999 rule (zero remains valid), so matched_without_valid_price is kept separate. |
| Coverage & Scope — Canonical Retained Sections by Institution Profile | `179` | [`71_coverage_canonical_by_institution`](metabase/questions/71_coverage_canonical_by_institution.sql) | Complete institution-profile coverage summary from canonical master_institution at one row per period_sortable × state × control × level × size × institution_type. institution_count counts source institution rows (including the explicit NULL-institution bucket), and bookstore_url_institution_count counts rows with a nonblank bookstore URL. |
| Coverage & Scope — Canonical Price Cells by Term | `180` | [`72_coverage_canonical_price_cells_by_term`](metabase/questions/72_coverage_canonical_price_cells_by_term.sql) | Current-snapshot price-cell coverage from canonical master_isbn term × ISBN rows. |
| FormatType Classification Coverage Over Time (2024+) | `83` | [`32_formattype_coverage_over_time`](metabase/questions/32_formattype_coverage_over_time.sql) | Share of canonical deduplicated material_costs items that carry a FormatType (and are thus OER/IA-classifiable). |
| OER/IA Rate Among Classified Materials (2024+) | `82` | [`31_oer_ia_rate_among_classified`](metabase/questions/31_oer_ia_rate_among_classified.sql) | OER/IA as a share of canonical Use materials that HAVE a FormatType classification (denominator excludes unclassified). |
| FormatType Coverage by Supply Status (2024+) | `162` | [`57_formattype_coverage_by_supply`](metabase/questions/57_formattype_coverage_by_supply.sql) | FormatType fill rate split by is_supply (#36) over raw comprehensive_data rows dated 2024+ with non-null ISBN13. |
| Coverage — Enrollment Fill-Potential (sections, 2024+) | `91` | [`33_coverage_enrollment_fill`](metabase/questions/33_coverage_enrollment_fill.sql) | Enrollment coverage among material-bearing Master Section rows. |
| DQ — Pricing → Catalog Match Rate by Period | `60` | [`10_dq_pricing_match_by_period`](metabase/questions/10_dq_pricing_match_by_period.sql) | Percent of pricing rows whose (section_id, isbn13) is found in catalog, by period. |
| DQ — Canonical Required Material format_count Distribution | `78` | [`27_dq_pricing_format_count_distribution_filtered`](metabase/questions/27_dq_pricing_format_count_distribution_filtered.sql) | format_count distribution for canonical Course Materials Use items that are inferred-required and have an exact pricing match. |

### Data Lineage — by School

ID `14` · [`data_lineage`](metabase/dashboards/data_lineage.json) · Walk one school's records through the selected teaching path: raw catalog, merged catalog, all raw pricing, pricing wide, section cost, Master Section, and Master Course. This dashboard is not the complete executable lineage: it omits the Course Materials Use/NoUse views, section_enrollment, material_costs, mailing/DQ branches, other master rollups, and file exports. The canonical execution and export diagrams are in repository SCHEMA.md. Set the School (unit_id) filter. Examples: 100937 Birmingham-Southern, 110404 Caltech, 112251 Claremont Graduate, 114433 Feather River CC, 115409 Harvey Mudd.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Lineage 1 — Raw Catalog (BMG course materials) | `84` | [`50_lineage_catalog`](metabase/questions/50_lineage_catalog.sql) | Raw/all original BMG course-material rows dated 2024+ for the selected school. |
| Lineage 2 — Merged (catalog × IPEDS × OER/IA) | `85` | [`51_lineage_merged`](metabase/questions/51_lineage_merged.sql) | Raw/all comprehensive_data records dated 2024+ — catalog + IPEDS + OER/IA + is_required_inferred + coverage flags. |
| Lineage 3 — Raw Cost (BMG pricing) | `86` | [`52_lineage_pricing`](metabase/questions/52_lineage_pricing.sql) | Raw/all BMG pricing_historical rows (one per vendor price option). |
| Lineage 4 — Pricing Wide (pivoted) | `87` | [`53_lineage_pricing_wide`](metabase/questions/53_lineage_pricing_wide.sql) | Pricing pivoted to one row per (section, ISBN): 18 price cells + has_buy/has_rent + ranges. |
| Lineage 5 — Section Cost | `88` | [`54_lineage_section_cost`](metabase/questions/54_lineage_section_cost.sql) | Cost rolled to one row per section (all-options + owned). |
| Lineage 6 — Master Section (wide record) | `89` | [`55_lineage_master_section`](metabase/questions/55_lineage_master_section.sql) | The wide section record — counts, OER/IA, coverage + enrollment fill-potential flags, cost. |
| Lineage 7 — Master Course (rollup) | `90` | [`56_lineage_master_course`](metabase/questions/56_lineage_master_course.sql) | Course-level rollup across sections — totals, OER/IA, coverage, cost (MIN/MAX/AVG). |

## Data quality dashboards

### Required Inference — Raw Data Quality (2024+)

ID `6` · [`filter_include_quality`](metabase/dashboards/filter_include_quality.json) · Legacy raw inferred-required versus not-inferred-required diagnostics and FormatType coverage by course level and period. FALSE is not synonymous with optional: it also retains literal-required, NULL-status, supply, placeholder, Canada, and other NoUse rows. These are not canonical Use release metrics.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Raw Inferred-Required vs Not-Inferred Counts by Course Level and Period | `49` | [`01_filter_include_counts`](metabase/questions/01_filter_include_counts.sql) | Legacy raw diagnostic of the inferred-required flag, grouped by course level and period (2024+). |
| FormatType Coverage by Course Level and Period (Filtered) | `50` | [`02_formattype_coverage`](metabase/questions/02_formattype_coverage.sql) | FormatType null coverage grouped by course level and period (canonical Use materials, inferred-required only) |
| Sections with Not-Inferred-Required Rows by Course Level and Period (2024+) | `51` | [`03_sections_no_materials`](metabase/questions/03_sections_no_materials.sql) | Legacy raw diagnostic counting sections containing rows where is_required_inferred is FALSE, grouped by course level and period (2024+). |

### OER/IA + Status (Filtered, 2024+)

ID `5` · [`oer_ia_status_filtered`](metabase/dashboards/oer_ia_status_filtered.json) · Replicates OER/IA + Status using has_required filter logic and period >= 2024 only

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| FormatType x OER x IA x Status (Filtered, 2024+) | `54` | [`04_filtered_formattype_status`](metabase/questions/04_filtered_formattype_status.sql) | FormatType cross-tabulated with OER/IA flags and book_status over canonical inferred-required items. |
| OER/IA Adoption Over Time (Filtered, 2024+) | `55` | [`05_filtered_oer_over_time`](metabase/questions/05_filtered_oer_over_time.sql) | OER and IA item counts by period over canonical inferred-required material_costs rows. total_enrollments counts each section once within its displayed OER/IA group. |

### Data Quality — Catalog

ID `7` · [`data_quality_catalog`](metabase/dashboards/data_quality_catalog.json) · DQ checks on the course catalog (is_required_inferred = TRUE only — analytical subset, period >= 2024). IPEDS coverage, NULL ISBN distribution, email validity, enrollment sanity.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| DQ — Catalog → IPEDS Match | `63` | [`13_dq_catalog_ipeds_match`](metabase/questions/13_dq_catalog_ipeds_match.sql) | Catalog rows split into IPEDS-matched / no-unit-id (Canadian, by design) / unit-id-not-in-IPEDS (closed/consolidated US schools). |
| DQ — Top Schools Missing from IPEDS | `64` | [`14_dq_catalog_top_unmatched_ipeds`](metabase/questions/14_dq_catalog_top_unmatched_ipeds.sql) | Top US schools whose unit_id isn't in IPEDS_2024 — typically closed/merged/consolidated institutions or sub-campuses tracked under main. |
| DQ — Top Schools by NULL ISBN | `65` | [`15_dq_catalog_top_null_isbn`](metabase/questions/15_dq_catalog_top_null_isbn.sql) | Top schools with NULL ISBN13 in the catalog. null_pct shows what proportion of that school's rows are missing an ISBN. |
| DQ — Null ISBN Breakdown by Placeholder Type | `74` | [`23_dq_null_isbn_breakdown`](metabase/questions/23_dq_null_isbn_breakdown.sql) | Top schools by NULL ISBN, split by placeholder string. |
| DQ — Enrollment Sanity | `66` | [`16_dq_catalog_enrollment_sanity`](metabase/questions/16_dq_catalog_enrollment_sanity.sql) | Catalog rows with anomalous enrollment vs seats_taken. |
| DQ — Email Validity | `67` | [`17_dq_catalog_email_validity`](metabase/questions/17_dq_catalog_email_validity.sql) | Catalog rows with email anomalies. email_null is dominated by source nulls (~26% of catalog has no email); the others are leaks from cleaning. |

### Data Quality — Pricing

ID `8` · [`data_quality_pricing`](metabase/dashboards/data_quality_pricing.json) · DQ checks on the pricing pipeline: dedupe stages, outliers, buy/rental discipline, format coverage, and pricing↔catalog matching.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| DQ — Critical Metrics (should be 0) | `68` | [`18_dq_critical_should_be_zero`](metabase/questions/18_dq_critical_should_be_zero.sql) | Headline indicators that must remain at 0. |
| DQ — Pricing Dedupe Stages | `56` | [`06_dq_pricing_dedupe_stages`](metabase/questions/06_dq_pricing_dedupe_stages.sql) | Row counts at each dedupe stage in the pricing import (raw → byte-identical → multi-instructor → most-recent snapshot → final) |
| DQ — Pricing Price Outliers | `57` | [`07_dq_pricing_price_outliers`](metabase/questions/07_dq_pricing_price_outliers.sql) | Row counts at price boundaries — bookstores often use $0 as placeholder; > $1000 is unusual |
| DQ — Pricing Buy/Rental Discipline | `58` | [`08_dq_pricing_buy_rental_discipline`](metabase/questions/08_dq_pricing_buy_rental_discipline.sql) | Source-data integrity for book_option, rental_days. |
| DQ — Digital Rental Days Consistency | `59` | [`09_dq_pricing_digital_rental_days`](metabase/questions/09_dq_pricing_digital_rental_days.sql) | Within (section, isbn) digital rental groups: all-NULL and all-set are consistent (benign); mixed is real DQ (~0.04% of pairs). |
| DQ — Pricing → Catalog Match Rate by Period | `60` | [`10_dq_pricing_match_by_period`](metabase/questions/10_dq_pricing_match_by_period.sql) | Percent of pricing rows whose (section_id, isbn13) is found in catalog, by period. |
| DQ — Pricing Wide format_count Distribution | `61` | [`11_dq_pricing_format_count_distribution`](metabase/questions/11_dq_pricing_format_count_distribution.sql) | How many of the 18 (option × condition × format) pivot cells are populated per (section, isbn). 0 means NULL-option only; 1 most common; long tail is rich data. |
| DQ — Top Unmatched Pricing Section Cohorts | `62` | [`12_dq_pricing_top_unmatched_sections`](metabase/questions/12_dq_pricing_top_unmatched_sections.sql) | Top (unit_id, period) cohorts by raw pricing sections with no exact section_id match in comprehensive_data. |
| DQ — Raw Physical Rental Rows per (Section × Item) | `72` | [`21_dq_rental_rows_per_pair_physical`](metabase/questions/21_dq_rental_rows_per_pair_physical.sql) | Histogram of raw vendor physical rental rows per (section, isbn) pair across all pricing data. |
| DQ — Raw Digital Rental Rows per (Section × Item) | `73` | [`22_dq_rental_rows_per_pair_digital`](metabase/questions/22_dq_rental_rows_per_pair_digital.sql) | Histogram of raw vendor digital rental rows per (section, isbn) pair across all pricing data. |
| DQ — Raw Digital Rental Period Length Distribution | `70` | [`20_dq_rental_period_length_distribution`](metabase/questions/20_dq_rental_period_length_distribution.sql) | Histogram of non-NULL rental_days values across all raw vendor digital rental rows. |
| DQ — Rental Row-Shape Distribution per (Section × Item) | `69` | [`19_dq_rental_rows_per_section_item`](metabase/questions/19_dq_rental_rows_per_section_item.sql) | Distinct (physical, digital, total) raw vendor rental row-count shapes across all (section, isbn) pairs, with how many pairs share each shape. |

### Data Quality — Raw Pricing + Canonical Required Materials

ID `11` · [`data_quality_pricing_filtered`](metabase/dashboards/data_quality_pricing_filtered.json) · Raw vendor pricing DQ across the full pricing population, plus a canonical required-material format_count comparison from matched inferred-required material_costs items (Q27). Q27 is not a filtered raw-pricing population.

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| DQ — Critical Metrics (should be 0) | `68` | [`18_dq_critical_should_be_zero`](metabase/questions/18_dq_critical_should_be_zero.sql) | Headline indicators that must remain at 0. |
| DQ — Pricing Dedupe Stages | `56` | [`06_dq_pricing_dedupe_stages`](metabase/questions/06_dq_pricing_dedupe_stages.sql) | Row counts at each dedupe stage in the pricing import (raw → byte-identical → multi-instructor → most-recent snapshot → final) |
| DQ — Pricing Price Outliers | `57` | [`07_dq_pricing_price_outliers`](metabase/questions/07_dq_pricing_price_outliers.sql) | Row counts at price boundaries — bookstores often use $0 as placeholder; > $1000 is unusual |
| DQ — Pricing Buy/Rental Discipline | `58` | [`08_dq_pricing_buy_rental_discipline`](metabase/questions/08_dq_pricing_buy_rental_discipline.sql) | Source-data integrity for book_option, rental_days. |
| DQ — Digital Rental Days Consistency | `59` | [`09_dq_pricing_digital_rental_days`](metabase/questions/09_dq_pricing_digital_rental_days.sql) | Within (section, isbn) digital rental groups: all-NULL and all-set are consistent (benign); mixed is real DQ (~0.04% of pairs). |
| DQ — Pricing → Catalog Match Rate by Period | `60` | [`10_dq_pricing_match_by_period`](metabase/questions/10_dq_pricing_match_by_period.sql) | Percent of pricing rows whose (section_id, isbn13) is found in catalog, by period. |
| DQ — Canonical Required Material format_count Distribution | `78` | [`27_dq_pricing_format_count_distribution_filtered`](metabase/questions/27_dq_pricing_format_count_distribution_filtered.sql) | format_count distribution for canonical Course Materials Use items that are inferred-required and have an exact pricing match. |
| DQ — Top Unmatched Pricing Section Cohorts | `62` | [`12_dq_pricing_top_unmatched_sections`](metabase/questions/12_dq_pricing_top_unmatched_sections.sql) | Top (unit_id, period) cohorts by raw pricing sections with no exact section_id match in comprehensive_data. |
| DQ — Raw Physical Rental Rows per (Section × Item) | `72` | [`21_dq_rental_rows_per_pair_physical`](metabase/questions/21_dq_rental_rows_per_pair_physical.sql) | Histogram of raw vendor physical rental rows per (section, isbn) pair across all pricing data. |
| DQ — Raw Digital Rental Rows per (Section × Item) | `73` | [`22_dq_rental_rows_per_pair_digital`](metabase/questions/22_dq_rental_rows_per_pair_digital.sql) | Histogram of raw vendor digital rental rows per (section, isbn) pair across all pricing data. |
| DQ — Raw Digital Rental Period Length Distribution | `70` | [`20_dq_rental_period_length_distribution`](metabase/questions/20_dq_rental_period_length_distribution.sql) | Histogram of non-NULL rental_days values across all raw vendor digital rental rows. |
| DQ — Rental Row-Shape Distribution per (Section × Item) | `69` | [`19_dq_rental_rows_per_section_item`](metabase/questions/19_dq_rental_rows_per_section_item.sql) | Distinct (physical, digital, total) raw vendor rental row-count shapes across all (section, isbn) pairs, with how many pairs share each shape. |

## Standalone cards

### Fall 2025 extracts and operational audits

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Sections — CA Public, Fall 2025 (all columns) | `93` | [`35_sections_ca_public_fall2025`](metabase/questions/35_sections_ca_public_fall2025.sql) | One row per material-bearing course section for California public institutions in Fall 2025 (period 2025-4), with every derived/enriched master_section column: institution enrichment, canonical item counts, OER/IA, ISBN/FormatType coverage, enrollment fields, retained-section audit fields, and cost. |
| Master ISBN dataset — Fall 2025 (material-listing distribution) | `157` | [`46_master_isbn_fall2025`](metabase/questions/46_master_isbn_fall2025.sql) | One record per unique (ISBN13, Title, Author, Format, FormatType) across ALL raw Fall-2025 (period 2025-4) catalog rows — built to reveal how the same/similar material is listed multiple ways so the team can decide whether to combine listings. |
| Top 100 Non-Supply ISBNs Missing FormatType (Fall 2025) | `164` | [`58_top100_nonsupply_missing_formattype`](metabase/questions/58_top100_nonsupply_missing_formattype.sql) | FormatType-enrichment candidates: raw Fall-2025 comprehensive_data rows with non-null ISBN13, NOT is_supply, and empty FormatType (NULL or ''). |
| Fall 2025 — Sections with no price choice, by institution class (#46) | `169` | [`63_no_price_choice_by_class`](metabase/questions/63_no_price_choice_by_class.sql) | BMG grant Fall-2025 material-bearing scope (period_sortable=2025-4; 4 BMG course levels × 6 teaching sectors). |
| Fall 2025 — UNITID × Bookstore URL Mapping | `172` | [`64_fall2025_unitid_bookstore_url_mapping`](metabase/questions/64_fall2025_unitid_bookstore_url_mapping.sql) | One row per distinct nonblank UNITID/bookstore URL pair from all imported Fall 2025 BMG pricing rows. |

### Same-item pricing analyses

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Fall 2025 — Same-ISBN Price by Required Status (is_required_inferred) | `165` | [`59_sameisbn_price_by_required_status`](metabase/questions/59_sameisbn_price_by_required_status.sql) | Issue #44: is the same ISBN priced differently when required vs optional/supplemental? |
| Fall 2025 — Same-ISBN Price by Literal book_status (required vs option/recommended) | `166` | [`60_sameisbn_price_by_book_status`](metabase/questions/60_sameisbn_price_by_book_status.sql) | Issue #44 robustness cut: uses material_costs literal-status source signals instead of is_required_inferred. required = at least one source book_status='required'; supplemental = at least one source book_status IN ('option','recommended'). |

### ISBN identity and title-cluster review

| Card | ID | Source | Scope / population |
|---|---:|---|---|
| Master ISBN — listing variability (Fall 2025) | `167` | [`61_master_isbn_variability`](metabase/questions/61_master_isbn_variability.sql) | Issue #45 finding over all raw Fall-2025 comprehensive_data rows with non-null ISBN13 (no canonical #58 Use or is_supply filter). |
| Master ISBN -- title-cluster blessed-ISBN13 candidates (Fall 2025) | `168` | [`62_master_isbn_title_cluster_candidates`](metabase/questions/62_master_isbn_title_cluster_candidates.sql) | BMG issue #45 part (b)/(c), over raw Fall-2025 comprehensive_data rows with non-null ISBN13 and nonblank normalized Title; no canonical #58 Use or is_supply filter is applied. |

## Models

| Model | ID | Source | Scope / population |
|---|---:|---|---|
| Master Institution by Term | `170` | [`model_master_institution`](metabase/models/master_institution.sql) | One row per period_sortable × unit_id represented by material-bearing Master Section rows from 2024 onward (#54). |
| Master ISBN by Term | `171` | [`model_master_isbn`](metabase/models/master_isbn.sql) | One row per period_sortable × ISBN13 from the canonical #58 Course Materials Use population (#55): post-2024, non-Canada, ISBN-bearing, non-supply, and not a no-details/no-materials placeholder. |
| Master Section | `158` | [`model_master_section`](metabase/models/master_section.sql) | One row per distinct canonical material_costs section key from 2024 onward. |
| Master Section — US Intro/Intermediate, Fall 2025 (BMG scope) | `159` | [`model_master_section_us_intro_fall2025`](metabase/models/master_section_us_intro_fall2025.sql) | The BMG grant analysis surface (#38): master_section filtered to Fall 2025 (period_sortable=2025-4), US institutions only (state excludes Canada + blank), intro/intermediate undergraduate course levels, and sections with at least one required canonical-Use material (required_count>=1, #58). |

## Coverage checks

- Dashboards: 14; questions: 70; models: 4
- Dashboard card placements: 79; unique dashboard-used questions: 61; standalone questions: 9
- Reused cards are intentionally listed under every dashboard where their JSON placement occurs.
- `.viz.json` and `.params.json` files are sidecars, not additional question cards.
- Every dashboard, card, and model stem resolves to an ID in `metabase/ids.json`.

## Maintenance

When adding or renaming a dashboard, card, or model, update its source frontmatter and `metabase/ids.json`, preserve dashboard JSON card order, then run `python3 scripts/generate_dashboards_reports.py --check`.
