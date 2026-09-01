---
notion-id: 3cbd9fdd-1a1a-80ee-884d-f4c7003aaf44
notion-url: https://app.notion.com/p/sqrlly/Dashboards-Reports-3cbd9fdd1a1a80ee884df4c7003aaf44
notion-sync: push
---

# Dashboards & Reports

This is the authoritative inventory of repository-defined Metabase dashboards, cards, and models. Dashboard order is conceptual: reporting surfaces, BMG Fall 2025 analysis, coverage/lineage, data quality, then standalone analytical extracts and review diagnostics. Card order follows each dashboard JSON layout. Scope descriptions come from SQL frontmatter; this document makes no claims about live query results.

## Reporting & analytical surfaces

### Course Materials Report

- ID: `13`
- Source: `metabase/dashboards/report.json`
- Scope: Parameterized report surface (#18). 13 dashboard filters (time, geography, institution, course, material) auto-mapped to every card. Overview = sections/OER/IA; Cost = required/optional/owned cost over the selected sections.

#### Report — Section / OER / IA Overview

- Stem: `30_report_overview`
- ID: `80`
- Source: `metabase/questions/30_report_overview.sql`
- Scope: Material-bearing sections and institutions, with canonical-Use OER/IA adoption, over the selected filters. Material status optionally restricts to sections carrying a matching material_costs item. Filters live on the dashboard.

#### Report — Materials Cost Summary

- Stem: `40_report_cost`
- ID: `81`
- Source: `metabase/questions/40_report_cost.sql`
- Scope: Canonical-Use required/optional materials cost over material-bearing sections (per-section, 2024+). Material status optionally restricts to sections carrying a matching material_costs item. Same dashboard filters as the overview.

### Course Materials Cost

- ID: `9`
- Source: `metabase/dashboards/course_materials_cost.json`
- Scope: Required-material cost by subject and level; owned (buy-only) vs all-options. Section grain, 2024+.

#### Required Materials Cost by Subject (2024+)

- Stem: `24_cost_required_by_subject`
- ID: `75`
- Source: `metabase/questions/24_cost_required_by_subject.sql`
- Scope: Average required-material cost per section by course subject, with owned (buy-only) comparison and price coverage. Cost from master_section (section_cost).

#### Owned vs All-Options Cost by Course Level (2024+)

- Stem: `25_cost_owned_vs_all`
- ID: `76`
- Source: `metabase/questions/25_cost_owned_vs_all.sql`
- Scope: Required-material cost — all options (incl. rental) vs owned (buy-only) — by course level. Owned reflects only materials that have a buy price.

### OER/IA Adoption

- ID: `10`
- Source: `metabase/dashboards/oer_ia_adoption.json`
- Scope: OER / Inclusive-Access adoption. Cards 31/32 use canonical Course Materials Use rows: card 31's OER/IA rate denominator is classified Use materials (FormatType present), while card 32's coverage denominator is all Use material rows. Card 26 divides section adoption by material-bearing master_section rows; card 05 counts inferred-required Use rows. Read absolute IA counts alongside FormatType coverage.

#### OER/IA Rate Among Classified Materials (2024+)

- Stem: `31_oer_ia_rate_among_classified`
- ID: `82`
- Source: `metabase/questions/31_oer_ia_rate_among_classified.sql`
- Scope: OER/IA as a share of canonical Use materials that HAVE a FormatType classification (denominator excludes unclassified).

#### FormatType Classification Coverage Over Time (2024+)

- Stem: `32_formattype_coverage_over_time`
- ID: `83`
- Source: `metabase/questions/32_formattype_coverage_over_time.sql`
- Scope: Share of canonical deduplicated material_costs items that carry a FormatType (and are thus OER/IA-classifiable). Pair with "OER/IA Rate Among Classified Materials".

#### OER/IA Section Adoption Over Time (2024+)

- Stem: `26_oer_ia_section_adoption`
- ID: `77`
- Source: `metabase/questions/26_oer_ia_section_adoption.sql`
- Scope: Share of material-bearing course sections with any OER / any Inclusive-Access canonical item, by period (from master_section). This is not a full section_enrollment denominator.

#### OER/IA Adoption Over Time (Filtered, 2024+)

- Stem: `05_filtered_oer_over_time`
- ID: `55`
- Source: `metabase/questions/05_filtered_oer_over_time.sql`
- Scope: OER and IA item counts by period over canonical inferred-required material_costs rows. total_enrollments counts each section once within its displayed OER/IA group.

## BMG Fall 2025 analysis

### BMG · Fall 2025 Overview

- ID: `18`
- Source: `metabase/dashboards/bmg_overview.json`
- Scope: The Fall 2025 grant-analysis landscape over material-bearing Master Section rows: section + enrollment counts and OER/IA + material coverage by institution class (control x 2yr/4yr) x A/B set. Set A has >=1 required canonical material_costs item and Set B is optional-only. Scope: 4 undergrad course levels x 6 real teaching sectors. Enrollment assignments originate from the complete section_enrollment population.

#### Fall 2025 — Section & Enrollment Counts by Institution Class x Set

- Stem: `39_fall2025_tally_counts_by_class`
- ID: `128`
- Source: `metabase/questions/39_fall2025_tally_counts_by_class.sql`
- Scope: Headline size table for the material-bearing Fall-2025 BMG grant scope. One row per control × level × set, where Set A has at least one required canonical item and Set B is optional-only. Enrollment values originate from section_enrollment but the displayed denominator is retained Master Section rows. enrollment_sum and enrollment_median use only present raw enrollment; institutions_count is per cell and does not add across A/B.

#### Fall 2025 — OER/IA Adoption & Material Coverage by Control x Level x Set

- Stem: `43_fall2025_tally_oer_ia_materials_coverage`
- ID: `132`
- Source: `metabase/questions/43_fall2025_tally_oer_ia_materials_coverage.sql`
- Scope: Per-section tally over material-bearing Master Section rows in the Fall-2025 BMG scope, showing OER/IA adoption, material load, and ISBN/FormatType coverage by institution control × level × A/B set. Rates are unweighted retained-section shares and *_count_avg columns are unweighted item counts per retained section. Set B is optional-only by definition; all rows carry at least one canonical material_costs item. Treat small institution-class cells as statistically noisy.

#### Fall 2025 Analysis — Set A: ≥1 required item (BMG grant scope)

- Stem: `37_fall2025_setA_has_required`
- ID: `126`
- Source: `metabase/questions/37_fall2025_setA_has_required.sql`
- Scope: BMG grant initial-analysis subset (issue #35), SET A. One row per material-bearing Fall-2025 course section (period 2025-4) in the agreed 4-course-level × 6-teaching-sector scope. SET A has at least one required canonical material_costs item: required_count > 0 under is_required_inferred (#1). All Master Section columns and retained-section audit fields are included. Set A is disjoint from Set B and together they exhaust the material-bearing Master Section scope; no-adoption/NoUse-only sections are outside this model. Use scripts/export_fall2025_subsets.sh for the full Parquet.

#### Fall 2025 Analysis — Set B: no required item (BMG grant scope)

- Stem: `38_fall2025_setB_no_required`
- ID: `127`
- Source: `metabase/questions/38_fall2025_setB_no_required.sql`
- Scope: BMG grant initial-analysis subset (issue #35), SET B. One row per material-bearing Fall-2025 course section (period 2025-4) in the agreed 4-course-level × 6-teaching-sector scope. SET B has no required canonical material_costs item: required_count = 0 under is_required_inferred (#1), so it is optional-only. No-adoption and NoUse-only sections are outside Master Section. All retained-section audit/enrollment columns remain visible. Set B is disjoint from Set A and together they exhaust the material-bearing Master Section scope. Use scripts/export_fall2025_subsets.sh for the full Parquet.

### BMG · Enrollment Data Quality

- ID: `17`
- Source: `metabase/dashboards/bmg_enrollment_dq.json`
- Scope: Missing enrollment and its assignment provenance among material-bearing Master Section rows. Summary: fill-source mix (own -> own_seats -> sibling_enroll -> sibling_seats -> class_median -> level_median), raw versus assigned totals, and imputed share by class and A/B set. The assignment values and medians originate from the complete section_enrollment population, while these cards display the narrowed release population. Gate enrollment-weighted results on enrollment_source; seats_taken=9999 is an invalid sentinel.

#### Fall 2025 — Enrollment Assignment Summary (source mix + raw vs assigned)

- Stem: `45_fall2025_enrollment_assignment_summary`
- ID: `134`
- Source: `metabase/questions/45_fall2025_enrollment_assignment_summary.sql`
- Scope: Companion to question 44, aggregating persisted enrollment fill (#32) over material-bearing Master Section rows. Per control x level x A/B set it reports fill-source counts, raw versus assigned enrollment, and the imputed share. The assignment ladder and medians still originate from the complete section_enrollment reference population; this card's denominator is the retained material-bearing scope. A/B membership uses required_count over canonical material_costs items.

#### Fall 2025 — Enrollment Missingness & Fill-Potential by Control × Level × Set

- Stem: `40_fall2025_tally_enrollment_fillpotential`
- ID: `129`
- Source: `metabase/questions/40_fall2025_tally_enrollment_fillpotential.sql`
- Scope: Per-section tally over the material-bearing Fall-2025 Master Section BMG scope, showing enrollment coverage and fill-potential by institution control × level × A/B set (A = >=1 required item, B = optional-only). Enrollment signals originate from the complete section_enrollment population, but this card's section denominator is narrowed to retained material-bearing sections. The three fill signals overlap, so missing_w_* do not sum to missing; unfillable is missing minus their union.

#### Fall 2025 — Section Enrollment Distribution by Control x Level (present only)

- Stem: `41_fall2025_tally_enrollment_distribution`
- ID: `130`
- Source: `metabase/questions/41_fall2025_tally_enrollment_distribution.sql`
- Scope: Distribution of present raw per-section enrollment among material-bearing Fall-2025 Master Section rows in the BMG grant scope, grouped by institution control × level. sections_n_present excludes NULL enrollment; enrollment_mean is the arithmetic mean and percentiles use quantile_cont. Enrollment values originate from section_enrollment, but no-adoption and NoUse-only sections are outside this card's denominator. Small class cells and the right-skewed tail should be interpreted cautiously.

#### Coverage — Enrollment Fill-Potential (sections, 2024+)

- Stem: `33_coverage_enrollment_fill`
- ID: `91`
- Source: `metabase/questions/33_coverage_enrollment_fill.sql`
- Scope: Enrollment coverage among material-bearing Master Section rows. Enrollment is NOT imputed here — these counts show how many retained sections missing enrollment have each fill signal available (has_enrollment_* are pure availability flags). Signals overlap (a section can have more than one), so the fillable rows do not sum to (missing − unfillable). pct_of_all_sections means all material-bearing sections in this model, not the complete section_enrollment population.

#### Fall 2025 — Section Enrollment Assignment (persisted fill + provenance)

- Stem: `44_fall2025_enrollment_assigned`
- ID: `133`
- Source: `metabase/questions/44_fall2025_enrollment_assigned.sql`
- Scope: Per-section enrollment fill for the material-bearing BMG grant scope (Fall 2025), reading persisted enrollment_assigned/enrollment_source values joined from the complete section_enrollment source (#32). Hierarchy: own -> own_seats -> sibling_enroll -> sibling_seats -> class_median -> level_median; medians are still computed over the full reference population, while this card displays only retained Master Section rows. Raw enrollments/seats_taken are never overwritten. A/B labels use required_count over canonical material_costs items. Metabase shows 2,000 rows; export for the full retained set.

### BMG · Cost Hypothesis

- ID: `16`
- Source: `metabase/dashboards/bmg_cost_hypothesis.json`
- Scope: Tests whether 2-year (esp. public) students pay more for course materials. Enrollment-weighted cost (top): Public 2yr students face ~$149/student in required materials vs ~$114 for Public 4yr (+31%), robust to enrollment imputation (own-only) and cost outliers (winsorized). Same-item price (second): for the IDENTICAL book, Public 2yr pays only ~$2 above market — so the class gap is overwhelmingly course-mix (which/how many books), NOT same-item price discrimination. Section-level cost medians by class (third) and the Top-125 same-item extract (bottom) support the read. All *_cost columns are (min+max)/2 summaries, NOT arithmetic means; cost aggregates use the canonical #58 Course Materials Use population; enrollment_assigned (#32) drives the weighting.

#### Fall 2025 — Hypothesis: Enrollment-Weighted Required Cost by Class

- Stem: `47_fall2025_hypothesis_enrollwt_cost`
- ID: `160`
- Source: `metabase/questions/47_fall2025_hypothesis_enrollwt_cost.sql`
- Scope: Tests whether 2-year (esp. public) students face higher required-material costs. Per institution class (control x 2yr/4yr), over Set A sections (>=1 required canonical #58 Course Materials Use item) in the BMG scope with a priced required cost. sec_median_cost = section-weighted median of required_cost_avg ((min+max)/2, NOT a mean). enrollwt_mean = enrollment-weighted mean $/student using master_section.enrollment_assigned (#32): SUM(cost x enrollment)/SUM(enrollment). enrollwt_mean_own = the same over own-enrollment sections only (enrollment_source='own') — the imputation sensitivity check; close agreement with enrollwt_mean means the result is not an artifact of imputed enrollment. enrollwt_mean_wins99 winsorizes cost at the class p99 (outlier robustness). total_burden_musd = SUM(cost x enrollment) in $M. FINDING: Public 2yr students face ~$149/student vs ~$114 for Public 4yr (+31%), robust to imputation and outliers. Small/noisy for-profit and private-2yr cells reported but not headline. Cost gap is mostly course-mix, not same-item price (see the same-item price question).

#### Fall 2025 — Hypothesis: Same-Item Price by Class (course-mix vs price)

- Stem: `48_fall2025_hypothesis_sameitem_price`
- ID: `161`
- Source: `metabase/questions/48_fall2025_hypothesis_sameitem_price.sql`
- Scope: Isolates same-item price discrimination from course-mix. Required canonical Use adoptions come from material_costs at one row per (period_sortable, section_id, isbn13), then price_min is demeaned by the SAME ISBN's median across adoptions (ISBNs with >=10 adoptions, so a cross-institution baseline exists). median_vs_market / mean_vs_market = dollars the class pays above (+) or below (-) the identical book's typical price; p25/p75 give the spread. FINDING: for the identical book, Public 2yr pays a mean +$1.63 above market vs Public 4yr's -$0.47 (medians $0.00 because most bookstores charge the same modal price; the effect is in the upper tail). This ~$2 same-item premium is small next to the ~$35/student class cost gap (see the enrollment-weighted cost question), so the class cost difference is overwhelmingly course-mix, not paying more for the same book. price_min is the cheapest available option (buy or rent, any condition/format) from material_costs.

#### Fall 2025 — Course-material cost by institution class (control x level x set)

- Stem: `42_fall2025_tally_cost_by_class`
- ID: `131`
- Source: `metabase/questions/42_fall2025_tally_cost_by_class.sql`
- Scope: Per-section course-material cost summaries for material-bearing Fall-2025 Master Section rows in the BMG scope, broken out by institution control × level × A/B set. All medians are section-weighted, not enrollment-weighted, and use the project (min+max)/2 summaries rather than arithmetic means. Set B is optional-only, so required-cost medians are NULL by construction; sections_priced_required counts retained sections with required_priced_count > 0. Treat small cells cautiously.

#### Top-125 ISBN Cost Extract — Fall 2025 (institution × course × faculty)

- Stem: `36_top125_isbn_cost_extract`
- ID: `125`
- Source: `metabase/questions/36_top125_isbn_cost_extract.sql`
- Scope: One row per canonical Use Fall-2025 (period 2025-4) section-adoption of the 125 most common ISBNs (ranked by distinct sections), read from material_costs at its canonical (period_sortable, section_id, isbn13) grain. Carries the deterministic catalog metadata, institution class (control, iclevel, instsize, sector), course, faculty, and the full pricing breakdown (buy/rental × new/used × physical/digital). Built for cost-difference analysis across institution classes (e.g. public 2-year vs private 4-year). Current result expectation: 178,058 adoptions; 112,968 (63.44%) have a matched price and 132,775 (74.57%) are inferred-required. Cost columns remain NULL when the material has no pricing match.

## Coverage & lineage

### Data Coverage & Fill-Potential

- ID: `15`
- Source: `metabase/dashboards/data_coverage.json`
- Scope: Where values are missing and how much could be recovered. Enrollment is NOT imputed — the fill-potential flags only quantify recoverability (~28% of missing enrollment is fillable from some signal). OER/IA missingness is ISBN-structural: internal inference fills 0, so raising coverage needs an external ISBN→OER/IA source.

#### Coverage — Enrollment Fill-Potential (sections, 2024+)

- Stem: `33_coverage_enrollment_fill`
- ID: `91`
- Source: `metabase/questions/33_coverage_enrollment_fill.sql`
- Scope: Enrollment coverage among material-bearing Master Section rows. Enrollment is NOT imputed here — these counts show how many retained sections missing enrollment have each fill signal available (has_enrollment_* are pure availability flags). Signals overlap (a section can have more than one), so the fillable rows do not sum to (missing − unfillable). pct_of_all_sections means all material-bearing sections in this model, not the complete section_enrollment population.

#### Coverage — OER/IA Classifiability & ISBN (2024+)

- Stem: `34_coverage_oer_ia_isbn`
- ID: `92`
- Source: `metabase/questions/34_coverage_oer_ia_isbn.sql`
- Scope: ISBN and OER/IA-classification coverage among canonical material_costs items rolled into material-bearing Master Section rows. The section denominator is not the complete catalog or section_enrollment population; raising FormatType coverage requires an external ISBN→OER/IA source.

### BMG Coverage & Scope

- ID: `19`
- Source: `metabase/dashboards/bmg_coverage_scope.json`
- Scope: Current snapshot coverage map from BMG source observations through canonical Course Materials, enrollment, pricing, and release populations. The Term filter defaults to the current snapshot term (2025-4) and applies to all 14 cards; card descriptions identify each source or canonical grain and denominator.

#### Coverage & Scope — Course Material Population by Term

- Stem: `65_coverage_course_material_population_by_term`
- ID: `173`
- Source: `metabase/questions/65_coverage_course_material_population_by_term.sql`
- Scope: Current-snapshot coverage from the canonical course_materials item-group spine (one period × section × ISBN, including one NULL-ISBN audit group per section), while reconstructed_source_rows sums source_row_count back to the enriched BMG source-row grain. All percentages named pct_*_of_item_groups use canonical item groups, not reconstructed source rows; Use-specific counts use the canonical retained Use population.

#### Coverage & Scope — Course Material Exclusion Overlap

- Stem: `66_coverage_course_material_exclusion_overlap`
- ID: `174`
- Source: `metabase/questions/66_coverage_course_material_exclusion_overlap.sql`
- Scope: Current-snapshot overlap audit at the canonical course_materials_post_2024 item-group grain (one period × section × ISBN audit group). Each row is an exact combination of independent Canada, supply, no-details, no-materials, and missing-ISBN flags; no mutually exclusive primary reason is imposed. included (no exclusions) is the zero-exclusion combination, while canonical_disposition exposes the canonical Use/NoUse result and population_classification_conflict separately exposes disagreement among source rows. reconstructed_source_rows returns to the enriched BMG source-row grain, while pct_of_term_item_groups uses canonical post-2024 item groups.

#### Coverage & Scope — Canonical Material Classification by Term

- Stem: `67_coverage_course_material_classification_by_term`
- ID: `175`
- Source: `metabase/questions/67_coverage_course_material_classification_by_term.sql`
- Scope: Current-snapshot classification frequencies over canonical material_costs Use items (one period × section × ISBN). A single source scan is expanded into six dimensions: catalog book_format, catalog FormatType, catalog book_status, inferred-required, OER, and IA. OER/IA NULLs are explicitly labeled unclassified. pct_of_term_dimension_items uses canonical item rows within each term and dimension, not source rows or sections.

#### Coverage & Scope — Complete Section Enrollment by Term

- Stem: `68_coverage_section_enrollment_by_term`
- ID: `176`
- Source: `metabase/questions/68_coverage_section_enrollment_by_term.sql`
- Scope: Current-snapshot enrollment coverage over the complete valid 2024+ section_enrollment spine, where section_count is the full section denominator and raw versus assigned enrollment remain distinct. The enrollment_source columns count assignment provenance. canonical_material_bearing_section_count is a separately named comparison to retained master_section rows and is not the full-spine denominator.

#### Coverage & Scope — Raw Pricing Options by Term

- Stem: `69_coverage_pricing_source_options_by_term`
- ID: `177`
- Source: `metabase/questions/69_coverage_pricing_source_options_by_term.sql`
- Scope: Current-snapshot source coverage at the BMG-owned pricing_historical observation grain, grouped by term × source option × condition × format with no canonical Use, required, or inferred-required filter. valid_price means price < 9999, so zero is valid; key counts use distinct raw section × ISBN pairs. This source denominator is deliberately different from canonical material_costs items.

#### Coverage & Scope — Canonical Use Pricing by Term

- Stem: `70_coverage_canonical_pricing_by_term`
- ID: `178`
- Source: `metabase/questions/70_coverage_canonical_pricing_by_term.sql`
- Scope: Current-snapshot pricing and classification coverage over canonical material_costs Use items (one period × section × ISBN). inferred_required_item_count uses catalog is_required_inferred; inferred_optional_item_count is its complement. item_count is the percentage denominator; section/course/institution/ISBN columns are distinct canonical denominators. has_pricing_match records exact source-key presence, while valid_price_item_count requires non-NULL price_min after the <9999 rule (zero remains valid), so matched_without_valid_price is kept separate. Option presence is independent of valid price and price_avg is not used.

#### Coverage & Scope — Canonical Retained Sections by Institution Profile

- Stem: `71_coverage_canonical_by_institution`
- ID: `179`
- Source: `metabase/questions/71_coverage_canonical_by_institution.sql`
- Scope: Complete institution-profile coverage summary from canonical master_institution at one row per period_sortable × state × control × level × size × institution_type. institution_count counts source institution rows (including the explicit NULL-institution bucket), and bookstore_url_institution_count counts rows with a nonblank bookstore URL. All section, course, material, source-required, inferred-required, inferred-optional, priced, supply, OER, IA, and enrollment metrics are summed across the profile. canonical_retained_section_count is the summed canonical retained-section denominator for every pct_* column; it is not the complete section_enrollment spine. source_required_section_count is the source-required count from section_book_status, while inferred-required and inferred-optional counts are the catalog-inferred split.

#### Coverage & Scope — Canonical Price Cells by Term

- Stem: `72_coverage_canonical_price_cells_by_term`
- ID: `180`
- Source: `metabase/questions/72_coverage_canonical_price_cells_by_term.sql`
- Scope: Current-snapshot price-cell coverage from canonical master_isbn term × ISBN rows. The 18 option × condition × format section-count cells are summed once per term and then normalized; canonical_section_item_occurrences = SUM(section_id_count) is the denominator, isbn_count is the number of canonical ISBN rows, and price_cell_occurrence_count can overlap across cells for the same section × ISBN. This is a canonical retained Use population, not raw pricing_historical observations.

#### FormatType Classification Coverage Over Time (2024+)

- Stem: `32_formattype_coverage_over_time`
- ID: `83`
- Source: `metabase/questions/32_formattype_coverage_over_time.sql`
- Scope: Share of canonical deduplicated material_costs items that carry a FormatType (and are thus OER/IA-classifiable). Pair with "OER/IA Rate Among Classified Materials".

#### OER/IA Rate Among Classified Materials (2024+)

- Stem: `31_oer_ia_rate_among_classified`
- ID: `82`
- Source: `metabase/questions/31_oer_ia_rate_among_classified.sql`
- Scope: OER/IA as a share of canonical Use materials that HAVE a FormatType classification (denominator excludes unclassified).

#### FormatType Coverage by Supply Status (2024+)

- Stem: `57_formattype_coverage_by_supply`
- ID: `162`
- Source: `metabase/questions/57_formattype_coverage_by_supply.sql`
- Scope: Issue #42. FormatType fill rate split by is_supply (#36) over raw comprehensive_data rows dated 2024+ with non-null ISBN13. Canada and NoUse rows remain included; no canonical #58 Use filter is applied. Empty FormatType = NULL or ''. Row denominators are all rows in this scope; ISBN denominators are distinct ISBN13s in this scope. share_of_all_empty_formattype_rows/isbns show how much of the overall gap each segment explains: supplies are a small slice -- 1.47% of empty-FormatType rows (72,587 of 4,945,299) and 0.70% of empty-FormatType distinct ISBNs (2,371 of 340,532). Supplies themselves are less well filled per-row (75.05% of supply rows empty vs 34.62% non-supply) and per-ISBN (94.09% of the 2,520 supply ISBNs never carry a FormatType vs 51.11% non-supply). Surprising bit: 149 of 2,520 supply ISBNs (5.91%) DO carry a FormatType -- mostly science_lab/art_drafting kits recorded as Book or Bundle (bundled with a textbook).

#### Coverage — Enrollment Fill-Potential (sections, 2024+)

- Stem: `33_coverage_enrollment_fill`
- ID: `91`
- Source: `metabase/questions/33_coverage_enrollment_fill.sql`
- Scope: Enrollment coverage among material-bearing Master Section rows. Enrollment is NOT imputed here — these counts show how many retained sections missing enrollment have each fill signal available (has_enrollment_* are pure availability flags). Signals overlap (a section can have more than one), so the fillable rows do not sum to (missing − unfillable). pct_of_all_sections means all material-bearing sections in this model, not the complete section_enrollment population.

#### DQ — Pricing → Catalog Match Rate by Period

- Stem: `10_dq_pricing_match_by_period`
- ID: `60`
- Source: `metabase/questions/10_dq_pricing_match_by_period.sql`
- Scope: Percent of pricing rows whose (section_id, isbn13) is found in catalog, by period. Drops here flag schema/format drift.

#### DQ — Canonical Required Material format_count Distribution

- Stem: `27_dq_pricing_format_count_distribution_filtered`
- ID: `78`
- Source: `metabase/questions/27_dq_pricing_format_count_distribution_filtered.sql`
- Scope: format_count distribution for canonical Course Materials Use items that are inferred-required and have an exact pricing match. One row is one material_costs (period, section, ISBN) item; this is the canonical comparison to the raw pricing DQ cards, not a filtered raw-pricing population.

### Data Lineage — by School

- ID: `14`
- Source: `metabase/dashboards/data_lineage.json`
- Scope: Walk one school's records through the selected teaching path: raw catalog, merged catalog, all raw pricing, pricing wide, section cost, Master Section, and Master Course. This dashboard is not the complete executable lineage: it omits the Course Materials Use/NoUse views, section_enrollment, material_costs, mailing/DQ branches, other master rollups, and file exports. The canonical execution and export diagrams are in repository SCHEMA.md. Set the School (unit_id) filter. Examples: 100937 Birmingham-Southern, 110404 Caltech, 112251 Claremont Graduate, 114433 Feather River CC, 115409 Harvey Mudd.

#### Lineage 1 — Raw Catalog (BMG course materials)

- Stem: `50_lineage_catalog`
- ID: `84`
- Source: `metabase/questions/50_lineage_catalog.sql`
- Scope: Raw/all original BMG course-material rows dated 2024+ for the selected school. Shows ALL columns for this stage so every field is traceable; no canonical Use/NoUse, supply, ISBN, or Canada exclusion is applied. Set the School (unit_id) filter. The LIMIT 200 is display-only.

#### Lineage 2 — Merged (catalog × IPEDS × OER/IA)

- Stem: `51_lineage_merged`
- ID: `85`
- Source: `metabase/questions/51_lineage_merged.sql`
- Scope: Raw/all comprehensive_data records dated 2024+ — catalog + IPEDS + OER/IA + is_required_inferred + coverage flags. Use, NoUse, Canada, NULL-ISBN, and supply rows remain included; this is lineage/DQ context, not a canonical-material denominator. Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter. The LIMIT 200 is display-only.

#### Lineage 3 — Raw Cost (BMG pricing)

- Stem: `52_lineage_pricing`
- ID: `86`
- Source: `metabase/questions/52_lineage_pricing.sql`
- Scope: Raw/all BMG pricing_historical rows (one per vendor price option). No inferred-required, canonical-Use, supply, or NoUse filter is applied; this is pricing lineage/DQ context. Shows all columns for this stage so every field is traceable. Optionally set the School (unit_id) filter. The LIMIT 200 is display-only.

#### Lineage 4 — Pricing Wide (pivoted)

- Stem: `53_lineage_pricing_wide`
- ID: `87`
- Source: `metabase/questions/53_lineage_pricing_wide.sql`
- Scope: Pricing pivoted to one row per (section, ISBN): 18 price cells + has_buy/has_rent + ranges. Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.

#### Lineage 5 — Section Cost

- Stem: `54_lineage_section_cost`
- ID: `88`
- Source: `metabase/questions/54_lineage_section_cost.sql`
- Scope: Cost rolled to one row per section (all-options + owned). Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.

#### Lineage 6 — Master Section (wide record)

- Stem: `55_lineage_master_section`
- ID: `89`
- Source: `metabase/questions/55_lineage_master_section.sql`
- Scope: The wide section record — counts, OER/IA, coverage + enrollment fill-potential flags, cost. Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.

#### Lineage 7 — Master Course (rollup)

- Stem: `56_lineage_master_course`
- ID: `90`
- Source: `metabase/questions/56_lineage_master_course.sql`
- Scope: Course-level rollup across sections — totals, OER/IA, coverage, cost (MIN/MAX/AVG). Shows ALL columns for this stage so every field is traceable. Set the School (unit_id) filter.

## Data quality dashboards

### Required Inference — Raw Data Quality (2024+)

- ID: `6`
- Source: `metabase/dashboards/filter_include_quality.json`
- Scope: Legacy raw inferred-required versus not-inferred-required diagnostics and FormatType coverage by course level and period. FALSE is not synonymous with optional: it also retains literal-required, NULL-status, supply, placeholder, Canada, and other NoUse rows. These are not canonical Use release metrics.

#### Raw Inferred-Required vs Not-Inferred Counts by Course Level and Period

- Stem: `01_filter_include_counts`
- ID: `49`
- Source: `metabase/questions/01_filter_include_counts.sql`
- Scope: Legacy raw diagnostic of the inferred-required flag, grouped by course level and period (2024+). The FALSE group means only "not inferred required": it also retains literal-required rows that fail the section-level inference rule, NULL statuses, supplies, placeholders, Canada, and other NoUse rows. This is not the canonical Use population or a release metric.

#### FormatType Coverage by Course Level and Period (Filtered)

- Stem: `02_formattype_coverage`
- ID: `50`
- Source: `metabase/questions/02_formattype_coverage.sql`
- Scope: FormatType null coverage grouped by course level and period (canonical Use materials, inferred-required only)

#### Sections with Not-Inferred-Required Rows by Course Level and Period (2024+)

- Stem: `03_sections_no_materials`
- ID: `51`
- Source: `metabase/questions/03_sections_no_materials.sql`
- Scope: Legacy raw diagnostic counting sections containing rows where is_required_inferred is FALSE, grouped by course level and period (2024+). FALSE means only "not inferred required": it also retains literal-required rows that fail the section-level inference rule, NULL statuses, supplies, placeholders, Canada, and other NoUse rows. This is not a count of sections with no materials and is not the canonical Use population or a release metric.

### OER/IA + Status (Filtered, 2024+)

- ID: `5`
- Source: `metabase/dashboards/oer_ia_status_filtered.json`
- Scope: Replicates OER/IA + Status using has_required filter logic and period >= 2024 only

#### FormatType x OER x IA x Status (Filtered, 2024+)

- Stem: `04_filtered_formattype_status`
- ID: `54`
- Source: `metabase/questions/04_filtered_formattype_status.sql`
- Scope: FormatType cross-tabulated with OER/IA flags and book_status over canonical inferred-required items. Item counts use material_costs grain; total_enrollments counts each section once within a displayed group.

#### OER/IA Adoption Over Time (Filtered, 2024+)

- Stem: `05_filtered_oer_over_time`
- ID: `55`
- Source: `metabase/questions/05_filtered_oer_over_time.sql`
- Scope: OER and IA item counts by period over canonical inferred-required material_costs rows. total_enrollments counts each section once within its displayed OER/IA group.

### Data Quality — Catalog

- ID: `7`
- Source: `metabase/dashboards/data_quality_catalog.json`
- Scope: DQ checks on the course catalog (is_required_inferred = TRUE only — analytical subset, period >= 2024). IPEDS coverage, NULL ISBN distribution, email validity, enrollment sanity.

#### DQ — Catalog → IPEDS Match

- Stem: `13_dq_catalog_ipeds_match`
- ID: `63`
- Source: `metabase/questions/13_dq_catalog_ipeds_match.sql`
- Scope: Catalog rows split into IPEDS-matched / no-unit-id (Canadian, by design) / unit-id-not-in-IPEDS (closed/consolidated US schools).

#### DQ — Top Schools Missing from IPEDS

- Stem: `14_dq_catalog_top_unmatched_ipeds`
- ID: `64`
- Source: `metabase/questions/14_dq_catalog_top_unmatched_ipeds.sql`
- Scope: Top US schools whose unit_id isn't in IPEDS_2024 — typically closed/merged/consolidated institutions or sub-campuses tracked under main.

#### DQ — Top Schools by NULL ISBN

- Stem: `15_dq_catalog_top_null_isbn`
- ID: `65`
- Source: `metabase/questions/15_dq_catalog_top_null_isbn.sql`
- Scope: Top schools with NULL ISBN13 in the catalog. null_pct shows what proportion of that school's rows are missing an ISBN.

#### DQ — Null ISBN Breakdown by Placeholder Type

- Stem: `23_dq_null_isbn_breakdown`
- ID: `74`
- Source: `metabase/questions/23_dq_null_isbn_breakdown.sql`
- Scope: Top schools by NULL ISBN, split by placeholder string. Globally only 3 placeholder values exist for NULL-ISBN rows — there are no genuinely-missing null-ISBN rows; "other" should always be 0. *No Book Details* (research/dissertation), *No Books Required* (explicit), *Bad Course* (DQ flag).

#### DQ — Enrollment Sanity

- Stem: `16_dq_catalog_enrollment_sanity`
- ID: `66`
- Source: `metabase/questions/16_dq_catalog_enrollment_sanity.sql`
- Scope: Catalog rows with anomalous enrollment vs seats_taken. Negative=bad data; sentinel 9999=uncapped courses; small/medium/large overage = real over-enrollment.

#### DQ — Email Validity

- Stem: `17_dq_catalog_email_validity`
- ID: `67`
- Source: `metabase/questions/17_dq_catalog_email_validity.sql`
- Scope: Catalog rows with email anomalies. email_null is dominated by source nulls (~26% of catalog has no email); the others are leaks from cleaning.

### Data Quality — Pricing

- ID: `8`
- Source: `metabase/dashboards/data_quality_pricing.json`
- Scope: DQ checks on the pricing pipeline: dedupe stages, outliers, buy/rental discipline, format coverage, and pricing↔catalog matching.

#### DQ — Critical Metrics (should be 0)

- Stem: `18_dq_critical_should_be_zero`
- ID: `68`
- Source: `metabase/questions/18_dq_critical_should_be_zero.sql`
- Scope: Headline indicators that must remain at 0. Non-zero values here mean a regression in dedupe, pivot, or classification logic.

#### DQ — Pricing Dedupe Stages

- Stem: `06_dq_pricing_dedupe_stages`
- ID: `56`
- Source: `metabase/questions/06_dq_pricing_dedupe_stages.sql`
- Scope: Row counts at each dedupe stage in the pricing import (raw → byte-identical → multi-instructor → most-recent snapshot → final)

#### DQ — Pricing Price Outliers

- Stem: `07_dq_pricing_price_outliers`
- ID: `57`
- Source: `metabase/questions/07_dq_pricing_price_outliers.sql`
- Scope: Row counts at price boundaries — bookstores often use $0 as placeholder; > $1000 is unusual

#### DQ — Pricing Buy/Rental Discipline

- Stem: `08_dq_pricing_buy_rental_discipline`
- ID: `58`
- Source: `metabase/questions/08_dq_pricing_buy_rental_discipline.sql`
- Scope: Source-data integrity for book_option, rental_days. Buy rows shouldn't have rental_days; rentals should — among other rules.

#### DQ — Digital Rental Days Consistency

- Stem: `09_dq_pricing_digital_rental_days`
- ID: `59`
- Source: `metabase/questions/09_dq_pricing_digital_rental_days.sql`
- Scope: Within (section, isbn) digital rental groups: all-NULL and all-set are consistent (benign); mixed is real DQ (~0.04% of pairs).

#### DQ — Pricing → Catalog Match Rate by Period

- Stem: `10_dq_pricing_match_by_period`
- ID: `60`
- Source: `metabase/questions/10_dq_pricing_match_by_period.sql`
- Scope: Percent of pricing rows whose (section_id, isbn13) is found in catalog, by period. Drops here flag schema/format drift.

#### DQ — Pricing Wide format_count Distribution

- Stem: `11_dq_pricing_format_count_distribution`
- ID: `61`
- Source: `metabase/questions/11_dq_pricing_format_count_distribution.sql`
- Scope: How many of the 18 (option × condition × format) pivot cells are populated per (section, isbn). 0 means NULL-option only; 1 most common; long tail is rich data.

#### DQ — Top Unmatched Pricing Section Cohorts

- Stem: `12_dq_pricing_top_unmatched_sections`
- ID: `62`
- Source: `metabase/questions/12_dq_pricing_top_unmatched_sections.sql`
- Scope: Top (unit_id, period) cohorts by raw pricing sections with no exact section_id match in comprehensive_data. The DQ snapshot compares all source pricing sections; no inferred-required or canonical-Use filter is applied.

#### DQ — Raw Physical Rental Rows per (Section × Item)

- Stem: `21_dq_rental_rows_per_pair_physical`
- ID: `72`
- Source: `metabase/questions/21_dq_rental_rows_per_pair_physical.sql`
- Scope: Histogram of raw vendor physical rental rows per (section, isbn) pair across all pricing data. X = rows per pair; Y = number of pairs. No catalog-derived inferred-required or canonical-Use filter is applied.

#### DQ — Raw Digital Rental Rows per (Section × Item)

- Stem: `22_dq_rental_rows_per_pair_digital`
- ID: `73`
- Source: `metabase/questions/22_dq_rental_rows_per_pair_digital.sql`
- Scope: Histogram of raw vendor digital rental rows per (section, isbn) pair across all pricing data. X = rows per pair; Y = number of pairs. No catalog-derived inferred-required or canonical-Use filter is applied.

#### DQ — Raw Digital Rental Period Length Distribution

- Stem: `20_dq_rental_period_length_distribution`
- ID: `70`
- Source: `metabase/questions/20_dq_rental_period_length_distribution.sql`
- Scope: Histogram of non-NULL rental_days values across all raw vendor digital rental rows. No catalog-derived inferred-required or canonical-Use filter is applied; physical rentals are outside this card.

#### DQ — Rental Row-Shape Distribution per (Section × Item)

- Stem: `19_dq_rental_rows_per_section_item`
- ID: `69`
- Source: `metabase/questions/19_dq_rental_rows_per_section_item.sql`
- Scope: Distinct (physical, digital, total) raw vendor rental row-count shapes across all (section, isbn) pairs, with how many pairs share each shape. No catalog-derived inferred-required or canonical-Use filter is applied.

### Data Quality — Raw Pricing + Canonical Required Materials

- ID: `11`
- Source: `metabase/dashboards/data_quality_pricing_filtered.json`
- Scope: Raw vendor pricing DQ across the full pricing population, plus a canonical required-material format_count comparison from matched inferred-required material_costs items (Q27). Q27 is not a filtered raw-pricing population.

#### DQ — Critical Metrics (should be 0)

- Stem: `18_dq_critical_should_be_zero`
- ID: `68`
- Source: `metabase/questions/18_dq_critical_should_be_zero.sql`
- Scope: Headline indicators that must remain at 0. Non-zero values here mean a regression in dedupe, pivot, or classification logic.

#### DQ — Pricing Dedupe Stages

- Stem: `06_dq_pricing_dedupe_stages`
- ID: `56`
- Source: `metabase/questions/06_dq_pricing_dedupe_stages.sql`
- Scope: Row counts at each dedupe stage in the pricing import (raw → byte-identical → multi-instructor → most-recent snapshot → final)

#### DQ — Pricing Price Outliers

- Stem: `07_dq_pricing_price_outliers`
- ID: `57`
- Source: `metabase/questions/07_dq_pricing_price_outliers.sql`
- Scope: Row counts at price boundaries — bookstores often use $0 as placeholder; > $1000 is unusual

#### DQ — Pricing Buy/Rental Discipline

- Stem: `08_dq_pricing_buy_rental_discipline`
- ID: `58`
- Source: `metabase/questions/08_dq_pricing_buy_rental_discipline.sql`
- Scope: Source-data integrity for book_option, rental_days. Buy rows shouldn't have rental_days; rentals should — among other rules.

#### DQ — Digital Rental Days Consistency

- Stem: `09_dq_pricing_digital_rental_days`
- ID: `59`
- Source: `metabase/questions/09_dq_pricing_digital_rental_days.sql`
- Scope: Within (section, isbn) digital rental groups: all-NULL and all-set are consistent (benign); mixed is real DQ (~0.04% of pairs).

#### DQ — Pricing → Catalog Match Rate by Period

- Stem: `10_dq_pricing_match_by_period`
- ID: `60`
- Source: `metabase/questions/10_dq_pricing_match_by_period.sql`
- Scope: Percent of pricing rows whose (section_id, isbn13) is found in catalog, by period. Drops here flag schema/format drift.

#### DQ — Canonical Required Material format_count Distribution

- Stem: `27_dq_pricing_format_count_distribution_filtered`
- ID: `78`
- Source: `metabase/questions/27_dq_pricing_format_count_distribution_filtered.sql`
- Scope: format_count distribution for canonical Course Materials Use items that are inferred-required and have an exact pricing match. One row is one material_costs (period, section, ISBN) item; this is the canonical comparison to the raw pricing DQ cards, not a filtered raw-pricing population.

#### DQ — Top Unmatched Pricing Section Cohorts

- Stem: `12_dq_pricing_top_unmatched_sections`
- ID: `62`
- Source: `metabase/questions/12_dq_pricing_top_unmatched_sections.sql`
- Scope: Top (unit_id, period) cohorts by raw pricing sections with no exact section_id match in comprehensive_data. The DQ snapshot compares all source pricing sections; no inferred-required or canonical-Use filter is applied.

#### DQ — Raw Physical Rental Rows per (Section × Item)

- Stem: `21_dq_rental_rows_per_pair_physical`
- ID: `72`
- Source: `metabase/questions/21_dq_rental_rows_per_pair_physical.sql`
- Scope: Histogram of raw vendor physical rental rows per (section, isbn) pair across all pricing data. X = rows per pair; Y = number of pairs. No catalog-derived inferred-required or canonical-Use filter is applied.

#### DQ — Raw Digital Rental Rows per (Section × Item)

- Stem: `22_dq_rental_rows_per_pair_digital`
- ID: `73`
- Source: `metabase/questions/22_dq_rental_rows_per_pair_digital.sql`
- Scope: Histogram of raw vendor digital rental rows per (section, isbn) pair across all pricing data. X = rows per pair; Y = number of pairs. No catalog-derived inferred-required or canonical-Use filter is applied.

#### DQ — Raw Digital Rental Period Length Distribution

- Stem: `20_dq_rental_period_length_distribution`
- ID: `70`
- Source: `metabase/questions/20_dq_rental_period_length_distribution.sql`
- Scope: Histogram of non-NULL rental_days values across all raw vendor digital rental rows. No catalog-derived inferred-required or canonical-Use filter is applied; physical rentals are outside this card.

#### DQ — Rental Row-Shape Distribution per (Section × Item)

- Stem: `19_dq_rental_rows_per_section_item`
- ID: `69`
- Source: `metabase/questions/19_dq_rental_rows_per_section_item.sql`
- Scope: Distinct (physical, digital, total) raw vendor rental row-count shapes across all (section, isbn) pairs, with how many pairs share each shape. No catalog-derived inferred-required or canonical-Use filter is applied.

## Standalone cards

### Fall 2025 extracts and operational audits

#### Sections — CA Public, Fall 2025 (all columns)

- Stem: `35_sections_ca_public_fall2025`
- ID: `93`
- Source: `metabase/questions/35_sections_ca_public_fall2025.sql`
- Scope: One row per material-bearing course section for California public institutions in Fall 2025 (period 2025-4), with every derived/enriched master_section column: institution enrichment, canonical item counts, OER/IA, ISBN/FormatType coverage, enrollment fields, retained-section audit fields, and cost. No-adoption and NoUse-only sections remain upstream and are not included.

#### Master ISBN dataset — Fall 2025 (material-listing distribution)

- Stem: `46_master_isbn_fall2025`
- ID: `157`
- Source: `metabase/questions/46_master_isbn_fall2025.sql`
- Scope: BMG task #37. One record per unique (ISBN13, Title, Author, Format, FormatType) across ALL raw Fall-2025 (period 2025-4) catalog rows — built to reveal how the same/similar material is listed multiple ways so the team can decide whether to combine listings. Missing-ISBN rows are INCLUDED as their own combos (blank source cells import as NULL, ~54% of catalog). This broad raw-listing audit includes NoUse/Canada rows and does not apply the canonical #58 Use filter; supplies are surfaced, not excluded. Counts per combo: NumReq/NumOpt/NumRec/NumBlnk by explicit book_status; NumBVAReq = BVA logic (is_required_inferred, inferred-required #1); NumTot = all rows. NumReq+NumOpt+NumRec+NumBlnk = NumTot by construction. First-non-blank Publisher & Imprint (from catalog) and Edition (from pricing_historical, per-ISBN; ~67% of priced ISBNs, blank for missing-ISBN combos). PublishedYear is not present in the source data (omitted). ~348,826 records; Metabase shows 2,000, full set exportable. Ordered by NumTot desc (most-listed first); re-sort by ISBN13 to cluster listing variants.

#### Top 100 Non-Supply ISBNs Missing FormatType (Fall 2025)

- Stem: `58_top100_nonsupply_missing_formattype`
- ID: `164`
- Source: `metabase/questions/58_top100_nonsupply_missing_formattype.sql`
- Scope: Issue #42. FormatType-enrichment candidates: raw Fall-2025 comprehensive_data rows with non-null ISBN13, NOT is_supply, and empty FormatType (NULL or ''). Canada and NoUse rows remain included; no canonical #58 Use filter is applied. Ranked by distinct section_id adoption count — the highest-leverage ISBNs to manually classify first. Same period scope as #37 (card 157); reuses its ISBN13/Title/Author grain. Scope population: 166,836 distinct non-supply ISBNs with empty FormatType, touching 822,303 distinct section adoptions and 1,204,681 catalog rows; this top 100 alone covers 87,291 of those section adoptions (~10.6%). Most rows are legitimate textbooks/references never assigned a FormatType (nursing, writing-handbook, and clinical-reference titles dominate); a handful are data-quality noise worth flagging separately rather than enriching — e.g. ISBN13 9780000043856 (blank Title/Author, a placeholder-looking ISBN) and 9789781111112 ("This Is A Digital Textbook..." with Author "Download This Text From Your D2l Acct", clearly a catalog placeholder, not a real ISBN lookup target).

#### Fall 2025 — Sections with no price choice, by institution class (#46)

- Stem: `63_no_price_choice_by_class`
- ID: `169`
- Source: `metabase/questions/63_no_price_choice_by_class.sql`
- Scope: BMG grant Fall-2025 material-bearing scope (period_sortable=2025-4; 4 BMG course levels × 6 teaching sectors). Required canonical items come from material_costs and are priced when price_min is non-null. A priced required item offers no price choice when price_min = price_max; a section has no price choice when it has at least one priced required item and all meet that condition. no_priced_required_material includes optional-only Set B plus required-bearing sections with no visible required price. pct_*_of_scope divides by retained material-bearing Master Section rows; price/format/IA fields come from material_costs and sentinel prices remain nulled upstream.

#### Fall 2025 — UNITID × Bookstore URL Mapping

- Stem: `64_fall2025_unitid_bookstore_url_mapping`
- ID: `172`
- Source: `metabase/questions/64_fall2025_unitid_bookstore_url_mapping.sql`
- Scope: One row per distinct nonblank UNITID/bookstore URL pair from all imported Fall 2025 BMG pricing rows. No required or inferred-required filter is applied. Multiple bookstore URLs for one UNITID remain separate; values are trimmed but otherwise source-preserved.

### Same-item pricing analyses

#### Fall 2025 — Same-ISBN Price by Required Status (is_required_inferred)

- Stem: `59_sameisbn_price_by_required_status`
- ID: `165`
- Source: `metabase/questions/59_sameisbn_price_by_required_status.sql`
- Scope: Issue #44: is the same ISBN priced differently when required vs optional/supplemental? For every Fall 2025 BMG-scope (period_sortable=2025-4, 4 intro/intermediate course levels, 6 real teaching sectors) canonical Use priced (section,isbn) adoption from material_costs, demeans price_min by that SAME ISBN's own overall median price_min. material_costs is already canonical at (period_sortable, section_id, isbn13), so catalog-row multiplicity cannot multiply pricing observations. Included ISBNs need >=10 total adoptions AND at least 1 adoption in each required status: 13,772 ISBNs and 573,151 adoptions. required_status uses canonical is_required_inferred for the section/ISBN. raw_median/mean_price show the unconditional gap (course-mix and book-identity effects included); median/mean_vs_same_isbn_baseline isolate the same-item effect by removing book identity. FINDING: raw median price is $9.14 higher for required ($63.99 vs $54.85, +16.7%), but the same-ISBN median residual is $0.00 for both groups and mean residuals differ by only $0.07 ($0.40 required vs $0.47 optional/supplemental). The raw gap is mainly a course-mix effect, not an economically meaningful same-item pricing effect. price_min is the cheapest available option (buy or rent, any condition/format) from material_costs. Confounds not controlled: institution/state/program mix within the pooled same-ISBN baseline — see GitHub issue #44 for deep-dive caveats.

#### Fall 2025 — Same-ISBN Price by Literal book_status (required vs option/recommended)

- Stem: `60_sameisbn_price_by_book_status`
- ID: `166`
- Source: `metabase/questions/60_sameisbn_price_by_book_status.sql`
- Scope: Issue #44 robustness cut: uses material_costs literal-status source signals instead of is_required_inferred. required = at least one source book_status='required'; supplemental = at least one source book_status IN ('option','recommended'). Excludes (section,isbn) materials carrying both statuses (mixed/ambiguous), preserving the source-row conflict behavior at the canonical material_costs grain. Same demeaning method as the primary same-ISBN question: subtract each ISBN's own overall median price_min, requiring >=10 total adoptions and at least 1 in each status. FINDING: essentially no premium survives this stricter literal cut — demeaned mean +$0.52 (required) vs +$0.35 (option/recommended), a ~$0.17 gap (median residual $0.00 for both) — versus a raw mean gap of ~$1.5 ($77.90 vs $76.38). The residual is a rounding-scale fraction of the ~$60 median price, plausibly channel-mix (required adoptions carry a rental option more often) rather than price discrimination. Read with the primary is_required_inferred question: no economically meaningful same-item required-vs-optional pricing effect at BMG scope. price_min = cheapest option (buy/rent, any condition/format) from material_costs.

### ISBN identity and title-cluster review

#### Master ISBN — listing variability (Fall 2025)

- Stem: `61_master_isbn_variability`
- ID: `167`
- Source: `metabase/questions/61_master_isbn_variability.sql`
- Scope: Issue #45 finding over all raw Fall-2025 comprehensive_data rows with non-null ISBN13 (no canonical #58 Use or is_supply filter). ISBN13 is a CLEAN KEY — of ~348,825 distinct non-null ISBN13s, ZERO carry more than one distinct Title/Author/Format/FormatType (isbn13_with_multi_* all 0; also serves as a re-runnable DQ guardrail — a future refresh introducing ISBN13-side variability would make these nonzero). So the "same book listed many ways" concern from the original #37 email is NOT at the ISBN13 level, and an ISBN13-keyed "blessed value" correction (as literally scoped in #45) is a no-op. The real variability is one level up: the same Title spans MANY distinct ISBN13s (editions/formats/printings) — ~32,088 titles carry >1 ISBN13, up to 137 ISBN13s for a single title. See card 62 for the title-cluster candidates. Blank-ISBN rows (~54% of catalog) can't be keyed by ISBN13 and are excluded.

#### Master ISBN -- title-cluster blessed-ISBN13 candidates (Fall 2025)

- Stem: `62_master_isbn_title_cluster_candidates`
- ID: `168`
- Source: `metabase/questions/62_master_isbn_title_cluster_candidates.sql`
- Scope: BMG issue #45 part (b)/(c), over raw Fall-2025 comprehensive_data rows with non-null ISBN13 and nonblank normalized Title; no canonical #58 Use or is_supply filter is applied. Since ISBN13-side variability is empirically zero (see the companion per-ISBN13 variability card -- 0 rows), the real 'same book listed many ways' problem runs the other direction: one normalized title (LOWER(TRIM(Title))) spread across many distinct ISBN13s. One row per normalized title with more than one distinct ISBN13 (36,691 titles as of this run). n_isbn13 = distinct ISBN13 count under the title; n_authors = distinct normalized Author strings across ALL rows under the title (not per-ISBN13); author_diversity_ratio = n_authors/n_isbn13, an UNVALIDATED review diagnostic only (low ratio, e.g. under 0.05, tends to flag non-identifying placeholder titles like 'Cognella Textbook'; high ratio, e.g. 0.4+, tends to reflect genuinely distinct books sharing a generic title like 'Macroeconomics' -- do NOT auto-collapse on this alone, per the #45 caution that a precision-estimated rule, following the #36 supply-classifier precedent, is still needed). blessed_isbn13/title/author/publisher/rows = the ISBN13 with the most catalog rows (adoption count) within the title cluster, i.e. the proposed canonical/modal candidate; every other ISBN13 in the cluster is an implicit non-blessed/duplicate candidate. Across all 36,691 clusters, 69,339 ISBN13s (417,112 rows) are non-blessed candidates; 17,894 clusters (40,645 ISBN13s) have n_authors=1, the strongest same-book signal. This is a REVIEW CANDIDATE list for BMG/Jeff sign-off, not an applied correction -- no pipeline table or column has been changed. Blank-ISBN13 rows are excluded (cannot be keyed by ISBN13, ~54% of catalog).

## Models

### Master Institution by Term

- Stem: `model_master_institution`
- ID: `170`
- Source: `metabase/models/master_institution.sql`
- Scope: One row per period_sortable × unit_id represented by material-bearing Master Section rows from 2024 onward (#54). Section/course/enrollment counts therefore cover retained canonical-material sections, while enrollment values originate in the complete section_enrollment source. Raw supply-aware required and comprehensive-data supply audits apply only to retained sections. The deterministic bookstore URL is an institution-metadata exception selected from all same-term pricing rows, preventing known URLs from disappearing when priced items fall outside canonical Use. NULL unit_id remains one unknown-institution bucket per term so narrowed Master Section totals reconcile. Priced-count names follow their actual required/optional status.

### Master ISBN by Term

- Stem: `model_master_isbn`
- ID: `171`
- Source: `metabase/models/master_isbn.sql`
- Scope: One row per period_sortable × ISBN13 from the canonical #58 Course Materials Use population (#55): post-2024, non-Canada, ISBN-bearing, non-supply, and not a no-details/no-materials placeholder. Includes deterministic metadata and conflict indicators, OER/IA, distinct institution/section/course counts, assigned-enrollment coverage and totals, all 18 wide-price-cell coverage counts, and institution-type section counts. A distinct section × ISBN spine prevents repeated catalog listings and rental terms from multiplying counts.

### Master Section

- Stem: `model_master_section`
- ID: `158`
- Source: `metabase/models/master_section.sql`
- Scope: One row per distinct canonical material_costs section key from 2024 onward. Material, inferred-required/optional, OER/IA, ISBN/FormatType, publisher, and cost fields aggregate the deduplicated Course Materials Use items. Enrollment and course/scope fields come from the complete section_enrollment source. Use/NoUse, no-details/no-materials, Canada, and supply fields are canonical course_materials sidecar audits for excluded item keys, including NULL-ISBN audit rows, that co-occur with retained material-bearing sections; they do not define this model's population. Use comprehensive_data for complete source-row audits. Slice by period_sortable, control, level, sector, or state in the GUI notebook builder. Backed by a materialized table. Gotchas: period_sortable YYYY-N (4=Fall); state 'CAN'=Canada; *_cost_avg=(min+max)/2 (NOT a mean); seats_taken=9999 is invalid.

### Master Section — US Intro/Intermediate, Fall 2025 (BMG scope)

- Stem: `model_master_section_us_intro_fall2025`
- ID: `159`
- Source: `metabase/models/master_section_us_intro_fall2025.sql`
- Scope: The BMG grant analysis surface (#38): master_section filtered to Fall 2025 (period_sortable=2025-4), US institutions only (state excludes Canada + blank), intro/intermediate undergraduate course levels, and sections with at least one required canonical-Use material (required_count>=1, #58). It retains the Master Section columns so Jeff can slice by control × level, sector, state, cost, or enrollment_assigned without rebuilding the scope. Backed by a cheap filter view over materialized master_section.

## Coverage checks

- Dashboards: 14; questions: 70; models: 4
- Dashboard card placements: 79; unique dashboard-used questions: 61; standalone questions: 9
- Reused cards are intentionally listed under every dashboard where their JSON placement occurs.
- `.viz.json` and `.params.json` files are sidecars, not additional question cards.
- Every dashboard, card, and model stem resolves to an ID in `metabase/ids.json`.

## Maintenance

When adding or renaming a dashboard, card, or model, update its source frontmatter and `metabase/ids.json`, preserve dashboard JSON card order, then run `python3 scripts/generate_dashboards_reports.py --check`.
