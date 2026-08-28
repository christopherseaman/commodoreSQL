# Course Material Monitor (CMM) ETL contract

Status: canonical release-facing contract for the current CommodoreSQL pipeline. This
document describes the implemented DuckDB pipeline and identifies decisions that are
not yet implemented. The authoritative column-level model remains [`SCHEMA.md`](SCHEMA.md)
and [`schema.dbml`](schema.dbml); SQL is the authority for executable semantics.

## 1. Naming, source snapshots, and release identity

Source-import names use the source owner prefix requested in the CMM update notes:
`BMG` = bookstore course-material/adoption source, `BVA` = bookstore/vendor pricing
or mailing-history source, `IPEDS` = institutional characteristics, and `CMM` = a
derived project-owned lookup or output. Derived/joined/enriched outputs omit `BVA`
(for example, **Course Materials**, **Costs**, and **Master section**). This naming
convention is documented in [`comms/26-08-17.md`](comms/26-08-17.md) and the requested
processing sequence in [`comms/media/CMM_files_processing.md`](comms/media/CMM_files_processing.md).

The checked-in schema snapshot records these current inputs and targets:

| Source snapshot (as recorded) | Imported target | Role |
|---|---|---|
| `DiscoveryExtract.20251215.csv` | `course_catalog_20251215` | BMG catalog/adoptions |
| `IPEDS_2024.csv` | `ipeds_data` | institution attributes |
| `OptOut_20251215.csv` | `opt_out` | email exclusion source |
| `panel_20260108.csv` | `panel` | panel response enrichment |
| `format_type_lookup.tsv` | `format_type_classification` | CMM OER/IA lookup |
| `BookPricing.Historical_20260224.csv` | `pricing_historical` | BVA bookstore price observations |
| `supply_keywords.tsv` | `supply_isbn_classification` | CMM supply classifier (2024+ titles) |

These filenames and approximate source sizes are recorded in [`schema.dbml`](schema.dbml)
(`source_files` and source-table notes). A release must record the actual source
filenames/date, pipeline commit, and configuration values used; no Spring 2026 source
snapshot is currently asserted by this repository.

## 2. Pipeline stages, transforms, and joins

The runnable order is `0_setup.sql`, `0b_state_region.sql`, `1_bookprices_import.sql`,
`1a_supply_classification.sql`, `1b_section_filter.sql`, `2_oer_classification.sql`,
`2b_pricing_oer_ia.sql`, `2c_pricing_wide.sql`, `2d_data_quality.sql`, then EDA
(`3_mailing_lists.sql`, `3b_material_costs.sql`, `4_merged_records.sql`), auto-discovered analysis models in
`scripts/sql/models/`, and discovered exports. The pipeline is envsubst-templated, uses
replace/recreate semantics, and is intended to be re-runnable;
see [`SCHEMA.md`](SCHEMA.md#pipeline) and [`scripts/sql/config.sql`](scripts/sql/config.sql).

### Import and enrichment

1. **Catalog/import (`0_setup.sql`).** Load the BMG DiscoveryExtract, normalize strings
   and emails, parse enrollment/seats, and derive `course_id`, `section_id`,
   `period_sortable`, and `period_date`. Load IPEDS, opt-out, and panel snapshots.
   `comprehensive_data` is initially the catalog left-joined to IPEDS by `unit_id`,
   opt-out and panel by cleaned email; format and supply fields are added in stage 2.
2. **State lookup (`0b_state_region.sql`).** Map catalog state codes to Census region
   and division; `CAN` is explicitly mapped to `Other`.
3. **Pricing import (`1_bookprices_import.sql`).** Parse BVA pricing fields and derive
   matching IDs. Dedupe byte-identical rows, then rows differing only by instructor,
   then retain the latest `pricing_date` per
   `(section_id, isbn13, book_option, book_condition, book_format, rental_days)`.
   Instructor names are retained as a comma-separated aggregate.
4. **Supply classification (`1a_supply_classification.sql`).** Build an ISBN-level,
   title-keyword include-AND-NOT-exclude classification over 2024+ catalog title
   variants. The lookup is [`scripts/sql/lookups/supply_keywords.tsv`](scripts/sql/lookups/supply_keywords.tsv);
   recall is keyword-bounded and unmatched/blank ISBN rows are not classified as supplies.
5. **Section required status (`1b_section_filter.sql`).** Create one
   `section_book_status` row per catalog `section_id`, with supply-aware
   `has_required = BOOL_OR(book_status='required' AND NOT is_supply)`. Set
   `is_required_inferred` on pricing, and stage 2 sets it on the recreated catalog join.
6. **Catalog classification (`2_oer_classification.sql`).** Join the FormatType lookup,
   supply ISBN table, IPEDS, panel, opt-out, and section status into
   `comprehensive_data`. OER/IA are NULL when FormatType is absent; category fields
   default to `unknown` when there is no lookup match. This stage owns the enriched/raw
   catalog rows and the row-level post-2024 Use/NoUse/Canada contract and creates four
   direct population views (#58).
7. **Pricing enrichment and wide form.** [`scripts/sql/2b_pricing_oer_ia.sql`](scripts/sql/2b_pricing_oer_ia.sql)
   joins OER/IA to pricing at `(section_id, isbn13)` using `BOOL_OR`. [`scripts/sql/2c_pricing_wide.sql`](scripts/sql/2c_pricing_wide.sql)
   pivots to one row per `(section_id, isbn13)`, preserving rental-term range and
   required/all-material views. Its reverse-enrichment fields remain temporarily for
   compatibility and raw pricing DQ; they are not canonical catalog ownership.
8. **Canonical material stage (`3b_material_costs.sql`).** Build materialized `section_enrollment` (the exact section
   assignment owner) and `material_costs`, one row per
   `(period_sortable, section_id, isbn13)` canonical Use item. `material_costs` is LEFT-enriched
   from `pricing_wide`, so items without a pricing-row match or valid price remain; catalog-owned fields come from
   `comprehensive_data`, while pricing fields include bookstore URL, all 18 cells, format/price
   bounds, rental range, and buy bounds.
9. **Aggregation (`4_merged_records.sql`).** Build `section_cost` from `material_costs`, then
   materialize `master_section` and views `master_course`, `master_course_material`, and the
   Fall 2025 BMG scope projection. `master_section` is exactly the one-row-per-section rollup of
   canonical `material_costs`; it joins section dimensions and assigned enrollment from the
   independent full-population `section_enrollment` table, and every price/cost field from
   `section_cost`.
10. **Release rollups and sample membership (`scripts/sql/models/`).** The runner materializes
   the canonical bare SELECTs as `master_institution`, `master_isbn`, and
   `sample10_section_ids`. Export wrappers and Metabase Models select these tables rather
   than carrying independent copies of their aggregation or sampling logic.

## 3. Table/data dictionary (contract grains)

The following is the release-facing grain dictionary. Types and complete columns are
authoritative in [`schema.dbml`](schema.dbml); common values/formats below are the
values used by current SQL.

The complete Master Section column-by-column source, aggregation, denominator, NULL, and
business-label mapping is [`MASTER-SECTION-DICTIONARY.md`](MASTER-SECTION-DICTIONARY.md).

| Table/view | Grain / key | Key fields (type; common values or format) | Upstream source / intended analysis |
|---|---|---|---|
| `course_catalog_20251215` | one source catalog row | `unit_id` INTEGER; `period_sortable` `YYYY-N`; `course_id`, `section_id` VARCHAR | BMG DiscoveryExtract; adoption and coverage denominators |
| `ipeds_data` | one institution (`unitid`) | `sector`, `iclevel`, `control`, `instsize` VARCHAR descriptors; enrollment INTEGER | IPEDS snapshot; institution stratification |
| `opt_out` / `panel` | one cleaned email per source row | `email` VARCHAR lowercase/trimmed; response year VARCHAR | BVA/CMM mailing enrichment and exclusions |
| `state_region` | one state/province code | `state`, `region`, `division` VARCHAR | Static Census-style geography enrichment and QA reference |
| `format_type_classification` | one FormatType | `is_oer`, `is_ia` BOOLEAN; category VARCHAR | CMM lookup; OER/IA classification |
| `supply_isbn_classification` | one classified ISBN | `isbn13` VARCHAR; category VARCHAR | CMM keyword lookup; supply audit |
| `section_book_status` | one `section_id` | `has_required` BOOLEAN | Catalog + supply classification; required inference |
| `comprehensive_data` | catalog/adoption row | source fields plus classification, coverage, enrollment, placeholder, geography, and Use/NoUse booleans | Catalog × IPEDS × email × FormatType × section status; authoritative enriched/raw catalog rows and row population |
| `course_materials_post_2024` / `course_materials_use` / `course_materials_no_use` / `course_materials_canada` | catalog/adoption row | direct filtered projections of `comprehensive_data` | Stable release populations; Canada is a post-2024 NoUse subset |
| `pricing_historical` | `(section_id, isbn13, book_option, book_condition, book_format, rental_days)` | option `buy`/`rental`; condition `new`/`used`/NULL; format `physical`/`digital`/NULL; price DECIMAL | BVA pricing snapshot after dedupe; per-term price analysis |
| `pricing_wide` / `pricing_wide_filtered` | one `(section_id, isbn13)`; filtered view is inferred-required | 18 option/condition/format price cells; `format_count`, `price_min/max`, `rental_days_min/max`; filtered `is_required_inferred=TRUE` | Reverse-enrichment compatibility and raw pricing DQ; not canonical catalog ownership |
| `section_enrollment` | one `(period_sortable, section_id)` | authoritative raw enrollment/flags, scope dimensions, exact `enrollment_assigned`, `enrollment_source` | Enriched catalog section spine; authoritative section-enrollment owner |
| `material_costs` | one `(period_sortable, section_id, isbn13)` canonical Use item | catalog-owned item metadata/flags; term/ISBN metadata contract; bookstore URL; all 18 price cells; format/price bounds; rental range; buy bounds; `has_pricing_match`; conflict signals | `comprehensive_data` Use spine LEFT-enriched from `pricing_wide`; retains items without a pricing row or valid price |
| `section_cost` | one `(period_sortable, section_id)` represented by `material_costs` | required/optional total and buy-only bounds; priced counts | `material_costs`; section cost coverage; downstream aggregate, not item input |
| `master_section` | one `(period_sortable, section_id)` represented by `material_costs` | canonical material counts, OER/IA, retained-section sidecar audits, coverage, enrollment fill, costs | `material_costs` + `section_cost`, with section/enrollment fields from `section_enrollment`; material-bearing release population |
| `master_course` | one `(course_id, period_sortable)` | section/material/enrollment rollups; course cost rollup | `master_section`/`section_cost`; course-level analysis |
| `master_course_material` | course-period-publisher-status group | material instances, sections using, seats affected | `material_costs`; publisher/material distribution |
| `master_section_us_intro_fall2025` | one selected `section_id` | Fall 2025, required-bearing, US intro/intermediate sections | Filtered `master_section`; BMG initial-analysis surface |
| `master_institution` | one `(period_sortable, unit_id)` represented by `master_section` | 36 institution/material-section coverage fields; NULL unit is an explicit unknown bucket when present | material-bearing `master_section` plus deterministic URL metadata from all same-term `pricing_wide` rows |
| `master_isbn` | one `(period_sortable, isbn13)` | 44 metadata, DQ, coverage, price-cell, and institution-type fields | Rollup of `material_costs`; ISBN-term release and Metabase model |
| `sample10_section_ids` | one selected full-population `section_id` | period, stable 64-bit MD5 prefix, bucket 0 | `section_enrollment`; canonical membership joined back to every sampled pipeline stage (#53) |
| `master_mailing`, `recent_periods`, `current_mailing`, state views | unique cleaned email / latest-period selector / filtered views | most recent period; state views include CA/TX/FL/NY/other | Catalog + opt-out/panel; mailing outputs |
| `__data_quality_metrics` and six `__data_quality_*` drill-down tables | metric row or named top-N/distribution grain | counts for catalog, pricing, joins, ISBN, and wide-pivot checks | Snapshot DQ surfaces created by `2d_data_quality.sql`; diagnostic, not analysis facts |

`email_issues.tsv` is a file audit emitted during import, not a persistent DuckDB table.
The optional legacy `5_univariate_summaries.sql` and `6_crosstab_summaries.sql` files are not
in `run_sql.sh` and therefore are not part of the canonical pipeline above.

### Duplicate collapse and conflict signals

Pricing source duplicates collapse in `pricing_historical` in three stages: byte-identical
rows, rows differing only by instructor, and latest `pricing_date` at the natural pricing key.
Residual pricing multiplicity is expected for rental terms and is collapsed by `pricing_wide`.
Catalog rows collapse to one `material_costs` row per `(period_sortable, section_id, isbn13)`.
Variant counts and metadata-conflict flags expose disagreements in catalog title, author,
publisher, format, or FormatType; canonical catalog values are selected deterministically from
catalog values, never copied from reverse-enriched pricing fields. These signals are DQ evidence,
not silent deduplication.

## 4. Selection, inclusion, and exclusion rules

- `section_id` is `unit_id::dept_code::course_number::section::period_sortable`; the
  period is part of the key. `course_id` omits section and period. A section means one
  section offering in one period, not a cross-period course.
- `master_section` is one row for every distinct `(period_sortable, section_id)` represented by a
  canonical Use item in `material_costs`. The current snapshot has 6,983,049 such sections.
  `section_enrollment` independently preserves all valid 2024+ section/enrollment denominators,
  including no-ISBN and no-adoption sections retained by #20.
- At row grain, Use means post-2024, not Canada, non-null ISBN, not supply, not
  `no_details`, and not `no_materials`. NoUse is the exact post-2024 complement; both are false
  before 2024. Canada is also exposed separately and is wholly NoUse. The imported
  `ISBN13` column is numeric, so blank source cells arrive as NULL; nonstandard numeric
  pseudo-SKUs remain eligible unless the supply classifier excludes them.
- `no_details` means title exactly `*No Book Details*`. `no_materials` means title exactly
  `*No Books Required*` or `supply_category='placeholder_no_material'`. These and the other
  exclusion booleans can overlap, so no lossy single exclusion-reason field is stored.
- Supplies remain auditable across all source rows in `comprehensive_data` (#36), while all master
  material, OER/IA, publisher, ISBN/FormatType, and cost measures consume `material_costs`.
  Master Section's supply/NoUse/placeholder/Canada fields are sidecar audits limited to excluded
  source rows that co-occur with a retained material-bearing section. The classifier is
  precision-oriented and keyword-bounded, not an exhaustive supply census.
- Required classification is `is_required_inferred`: for 2024+, a `required` row when
  the section has a non-supply required item, otherwise a NULL-status fallback when it
  does not. Raw `book_status` remains available and is not overwritten.
- The BMG Set A/B release scope is course level in introductory/general undergraduate,
  intermediate undergraduate, non-degree credit, or uncategorized, and sector in the
  six real teaching-sector descriptors listed in [`HANDOFF.md`](HANDOFF.md). Set A is
  `required_count >= 1`; Set B is `required_count = 0`; their section totals must be
  reported together and reconcile to the same material-bearing scope denominator. Set B is
  therefore **optional-only**, not a no-adoption population.
- The named Fall 2025 US intro/intermediate view further selects
  `period_sortable='2025-4'`, `required_count >= 1`, the two intro/intermediate levels,
  and `state NOT IN ('CAN','')`; it is a filtered projection in
  [`scripts/sql/4_merged_records.sql`](scripts/sql/4_merged_records.sql#L423).
- `master_institution` retains every material-bearing `master_section` row. Sections without `unit_id`
  roll into one explicitly documented unknown-institution row per term; they receive no
  bookstore URL. As an explicit institution-metadata exception, the canonical URL is the most
  frequent nonblank URL among all of that unit's `pricing_wide` rows in the same encoded term,
  with lexical tie-breaking; it is not restricted to canonical Use items.
- `master_isbn` uses the canonical material spine: Use rows with an ISBN. Canada, supply,
  no-details, no-material, and no-ISBN rows are therefore absent; non-978/979 pseudo-SKUs remain
  eligible unless `is_supply` catches them (#41). Catalog duplicates collapse before joins;
  canonical metadata is lexical `MIN`, while variant counts and `metadata_conflict` retain DQ.
- `material_costs` is the approved item-level input: one row per
  `(period_sortable, section_id, isbn13)` after the canonical Use predicate. It is built from
  catalog-owned `comprehensive_data` fields and LEFT-enriched from `pricing_wide`, so every Use
  item survives, including items with no pricing match. `section_cost` and `master_isbn` consume
  this table; `master_section` is its exact section-key rollup and receives all price/cost fields
  from `section_cost`.
- The per-term Master Section release is a direct term filter of materialized `master_section`.
  It contains only sections represented by the canonical Use/material population. Issue #58 is
  implemented by this release contract, while full section/enrollment analysis remains upstream
  and new-input readiness remains tracked in #51.
- Mailing outputs deduplicate by cleaned email, exclude opt-outs, choose the most
  recent period, and have state-specific views. Tie-breaking and mailing-history
  updates require confirmation when a source has multiple equally eligible rows.

## 5. Derived variables and cost semantics

| Variable | Contract |
|---|---|
| `period_sortable`, `period_date` | Winter/Spring/Summer/Fall map to `YYYY-1/2/3/4` and canonical dates Jan 1/Apr 1/Jul 1/Oct 1. |
| `course_id`, `section_id` | Composite IDs above; `UNKNOWN` segments expose missing source keys. |
| `is_oer`, `is_ia` | FormatType lookup results; NULL means not classifiable because FormatType is absent. At section level the definitive boolean is `BOOL_OR`; counts are the DQ comparison. |
| `is_supply`, `supply_category` | ISBN title-keyword result; unmatched/blank ISBN is false/NULL. |
| `is_post_2024`, `has_isbn`, `has_formattype`, `has_enrollment`, `has_enrollment_own_seats` | Row facts: 2024+ date, non-NULL ISBN, nonblank FormatType, non-NULL enrollment, and usable non-NULL seats below 9999. Section coverage/enrollment flags retain their documented aggregate meaning. |
| `no_details`, `no_materials`, `is_canada` | Independent row booleans defined by exact placeholder titles/category and `state='CAN'`; they can overlap. |
| `is_course_material_use`, `is_course_material_no_use` | Exact post-2024 partition defined above; both false pre-2024. |
| `enrollment_assigned`, `enrollment_source` | Owned by `section_enrollment`; raw enrollment first, usable `seats_taken < 9999`, sibling enrollment, sibling seats, control×level median, level median; source is `own`, `own_seats`, `sibling_enroll`, `sibling_seats`, `class_median`, `level_median`, or `none`. Raw values remain unchanged. Medians are per period over the four BMG levels × six teaching sectors. |
| `price_min`, `price_max` | Bounds over valid prices for a section/ISBN; prices `>= 9999` are nulled as sentinels. |
| `price_avg` and `*_cost_avg` | Legacy midpoint `(min + max) / 2.0`, not an arithmetic mean. Label this explicitly in every release/export. |
| `*_cost_total_*` | Sum of per-ISBN bounds over distinct priced Use materials, split by `is_required_inferred`. |
| `*_cost_owned_*` | Buy-option-only bounds; rentals are excluded. A rental-only material can count in total priced coverage while having NULL owned cost. |
| `rental_days_min/max` | Offered rental-term bounds; wide pricing collapses rental prices with `MAX`, so per-term analyses use `pricing_historical`. |

### Stakeholder-label mapping for the master exports

Repository names remain snake_case and make the aggregation grain explicit:

| Source workbook / Word label | Canonical output |
|---|---|
| Institution `section_id`, `course_id` | `section_count`, `course_count` |
| Nine course-level labels | normalized `<course_level>_section_count` columns |
| `material_count`, `required_count`, `Inferred_required_count`, `optional_count`, `supply_count`, `oer_count`, `ia_count` | corresponding `*_section_count` columns |
| `Req_priced_count`, `Opt_priced_count` | `required_priced_section_count`, `optional_priced_section_count`; the workbook prose has these reversed, but the output names follow actual status |
| Institution `isbn_count`, `enrollments`, `seats_taken` | `isbn_section_count`, `enrollment_section_count`, `seats_taken_section_count` |
| ISBN `unit_id_cnt`, `section_id_cnt`, `course_id_cnt` | `unit_id_count`, `section_id_count`, `course_id_count` |
| ISBN price-cell or institution-type label | normalized `<label>_count`; each is a distinct-section count |
| `Is_supply`, `enroll_cnt`, `enroll_tot` | `is_supply`, `enroll_cnt`, `enroll_tot` |

## 6. Coverage denominators and reporting rules

Always state the denominator and grain with every percentage or crosstab:

1. **Catalog coverage:** denominator = catalog rows or distinct `section_id`s, as labelled.
   `comprehensive_data` retains NoUse/no-ISBN rows; Use-based section coverage numerators are
   `isbn_count` and `classified_count`.
2. **Pricing coverage:** denominator = distinct `(section_id, ISBN13)` course-material
   keys in the selected catalog slice; numerator = `required_priced_count` or
   `optional_priced_count` (a valid `price_min` exists). Report total-price and
   buy-only coverage separately; do not use `has_buy` alone as a valid-price flag.
3. **Section cost:** denominator = all selected material-bearing `master_section` sections,
   including sections whose Use materials have no valid price; NULL cost means no valid bound,
   not zero cost or no material adoption.
4. **OER/IA:** denominator = Use course-material items/sections in the named
   slice; `has_formattype` is the classifiability denominator and `is_oer`/`is_ia` are
   not silently recoded from NULL to false at the raw-material level.
5. **Enrollment-weighted results:** denominator/weight must name whether the result
   uses `enrollment_assigned` or raw enrollment and report `enrollment_source` mix;
   imputed enrollment is not equivalent to observed enrollment.
6. **Master Institution counts:** section/enrollment/course-level denominators and all material,
   inferred-required/optional/OER/IA/ISBN, and cost measures use material-bearing
   `master_section` rows for the term×unit. Retained-section sidecar audit fields do not restore
   excluded full-population sections.
   `bookstore_url` remains the institution-level metadata exception selected deterministically
   from all same-term `pricing_wide` rows; it is not a catalog field. `required_section_count` is raw
   `section_book_status.has_required`, while
   `inferred_required_section_count` is `required_count > 0`.
   Required/optional priced names follow their actual statuses, correcting the reversed
   stakeholder prose. Enrollment totals use `enrollment_assigned`; valid-seat totals omit 9999.
7. **Master ISBN counts:** distinct-key and enrollment counts use the deduplicated
   material-cost section×ISBN spine. Every `price_*_count` counts sections with a non-NULL
   material-cost price cell,
   so rental terms and repeated catalog listings cannot multiply it. Institution-type counts
   likewise count distinct sections, not raw catalog or pricing rows.

The full release uses all rows meeting the stated scope. The reproducible sample is not a
random per-query draw. Rule `md5-prefix64-mod10-v1` interprets the first 64 bits of
`MD5(section_id)` as an unsigned integer and retains modulo-10 bucket zero in
`sample10_section_ids`. MD5 is used because DuckDB does not promise `hash()` stability across
versions. Membership is drawn from the complete `section_enrollment` population, not from
Master Section, so the stable 2,359,278-row membership and its existing fingerprint remain
unchanged. Joining that same membership table back to catalog, cost, institution, and ISBN stages
preserves whole section clusters and prevents stage-specific samples. The Master Section sample
export is the 698,578-row intersection of that membership with material-bearing Master Section.
Approximately 10%, rather than exactly 10%, is expected overall and within subgroups.

Only additive section-cluster totals can be estimated by multiplying the sample by ten.
Distinct institution and ISBN domain sizes cannot: high-frequency domains have a much higher
chance of appearing at least once. [`scripts/sql/exports/37_sample10_reconciliation.sql`](scripts/sql/exports/37_sample10_reconciliation.sql)
reports both cases explicitly. For each additive metric it estimates Horvitz-Thompson variance
from squared per-section contributions and applies a two-sided 99.9% normal-reference alarm
(`|z| <= 3.2905`). This represents whole-section clustering and unequal section weights; because
membership is a deterministic hash partition, treat the band as a pipeline-drift reference,
not a formal repeated-sampling confidence interval. The current reconciliation emits 192 checks:
176 additive checks, zero failures, and one sparse source cell explicitly marked not testable.

The four canonical materialized export tables retain `period_sortable`;
`scripts/export_cmm_masters.sh` splits `master_section`, `master_institution`, and
`master_isbn`, and `material_costs` without changing filters or calculations into four
release-dated CSVs per material-bearing term. Its default term discovery is based on 2024+ terms in
`material_costs`.
`scripts/sql/exports/35_master_institution_by_term.sql` and
`36_master_isbn_by_term.sql` provide combined all-term exports from the two rollup tables.
`scripts/sql/exports/40_material_costs_by_term.sql` provides the combined all-term
material-cost export. All four per-term files follow the #58 population contract. Full exports retain
`period_sortable` and combine all available terms without changing grain; per-term files are
direct term filters. The expected current `material_costs` baseline is 12,806,060 rows:
7,476,130 have a pricing-row match and 5,329,930 do not; 5,329,933 have NULL `price_min`
because three matched pricing rows also lack a valid price. Source-readiness
remains pending #51.
`scripts/sql/exports/38_cmm_release_reconciliation.sql` performs exact per-term checks from the
material-cost item and section spines through Master Section, Master Institution, and Master ISBN.
`39_cmm_release_key_reconciliation.sql` separately compares distinct `material_costs` section keys
with Master Section keys so the two large reconciliation states do not coexist. Every `is_match`
value is required to be true.

### Metabase population routing (#61)

Metabase is a presentation layer over the population contract above; a question must not
silently create a competing material or section denominator. Release-facing item and pricing
analyses use `material_costs` (or the equivalent canonical `course_materials_use` predicate where
raw catalog grain is intentionally needed). Release-facing section and enrollment denominators
use material-bearing `master_section`. A Master Section report with a dashboard material filter
applies that filter through distinct canonical `material_costs` section keys, then aggregates the
selected sections once. Full catalog/enrollment diagnostics must explicitly source
`comprehensive_data` or `section_enrollment` and label that broader denominator.

The grouped inventory below covers every tracked Metabase question, model, and dashboard.

| Artifact group | Tracked artifacts | Population contract |
|---|---|---|
| Canonical material-row questions | **02, 04–05, 31–32, 36, 48, 59–60, 63** | Use `material_costs` or the exact `course_materials_use` predicate at an explicitly named raw grain; required-status cuts are subsets of Use, not replacement population rules. |
| Canonical material-section rollups | **24–26, 30, 33–35, 37–45, 47, 54–56** | Read one-row-per-material-section denominators and canonical measures from `master_section`, `section_cost`, or their rollups. Questions 30 and 40 filter through distinct `material_costs` section keys only when the material dashboard filter is supplied. |
| Intentional raw catalog/listing/DQ questions | **01, 03, 13–18, 23, 46, 50–52, 57–58, 61–62** | May retain NoUse, Canada, supplies, and/or missing ISBNs as each diagnostic requires; descriptions must state the raw scope and that it is not a release denominator. |
| Intentional pricing-only DQ/lineage questions | **06–12, 19–22, 27, 53** | May use broad `pricing_historical`/`pricing_wide` rows to inspect dedupe, rental terms, matching, pivots, and outliers; these are not material or section denominators. |
| Models | `master_section`, `master_institution`, `master_isbn`, `master_section_us_intro_fall2025` | Master Section and Institution are material-bearing; Master ISBN is canonical Use-only; the BMG model is the documented Fall-2025 required-bearing subset. |
| Canonical material dashboards | `bmg_cost_hypothesis`, `bmg_enrollment_dq`, `bmg_overview`, `course_materials_cost`, `data_coverage`, `oer_ia_adoption`, `oer_ia_status_filtered`, `report` | Compose the canonical item and material-section questions above; dashboard descriptions state any narrower analytical subset. |
| Intentional DQ/lineage dashboards | `data_lineage`, `data_quality_catalog`, `data_quality_pricing`, `data_quality_pricing_filtered`, `filter_include_quality` | Present the explicitly labeled raw, pricing-only, lineage, or required-inference diagnostics above and do not define release populations. |

When an older question reconstructs a pre-#58 material predicate, migrate its presentation
logic to this routing contract (#61); do not treat the legacy predicate as an alternative
release definition.

## 7. Known pending Spring 2026 inputs and unresolved decisions

The August update notes say that two additional terms of course data are available,
but do not identify checked-in filenames or certify that they have been loaded. The
following are external pending inputs—not landed local tables or current pipeline facts:
**Spring 2026 BMG course materials**; 25 institution IPEDS IDs; two additional-term institution pricing
(`bva_ipeds_sample25`); BVA mailing-history update; an external Amazon/other pricing
snapshot (`cmm_external_pricing_YYYYMMDD`); discipline lookup (**`cmm_discipline`**); and
later campus-level inclusive-access data (`cmm_ia`). See [`comms/26-08-17.md`](comms/26-08-17.md).

Before a Spring 2026 release, confirm source filenames/snapshot dates, institution-ID
coverage, pricing-to-catalog key normalization, discipline join key, and bookstore URL
availability. The `no_details`/`no_materials` and Use/NoUse population rules are implemented
in the authoritative row flags. `#26` (whether “owned cost” covers all
required materials or only the buy-priced subset and how to label it) remains a PI
decision, as recorded in [`BMG-SUMMARY.md`](BMG-SUMMARY.md). Do not present #26 as
resolved until the authoritative SQL and schema are updated. The #61 presentation-layer
migration is complete; intentionally broad legacy/DQ cards are the explicit exceptions in the
routing inventory above, not alternative definitions of the release population.

## Evidence and change control

This contract is grounded in [`SCHEMA.md`](SCHEMA.md), [`schema.dbml`](schema.dbml),
[`HANDOFF.md`](HANDOFF.md), [`CLAUDE.md`](CLAUDE.md), [`README.md`](README.md),
[`BMG-SUMMARY.md`](BMG-SUMMARY.md), the August communications
([`26-08-05.md`](comms/26-08-05.md), [`26-08-14.md`](comms/26-08-14.md),
[`26-08-17.md`](comms/26-08-17.md)), and the executable SQL paths linked above.
When this document and SQL disagree, treat the SQL output and the authoritative schema
as the contract and record the discrepancy for correction; do not patch a release by
silently changing a denominator.
