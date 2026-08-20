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
(`3_mailing_lists.sql`, `4_merged_records.sql`), auto-discovered analysis models in
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
   default to `unknown` when there is no lookup match.
7. **Pricing enrichment and wide form.** [`scripts/sql/2b_pricing_oer_ia.sql`](scripts/sql/2b_pricing_oer_ia.sql)
   joins OER/IA to pricing at `(section_id, isbn13)` using `BOOL_OR`. [`scripts/sql/2c_pricing_wide.sql`](scripts/sql/2c_pricing_wide.sql)
   pivots to one row per `(section_id, isbn13)`, preserving rental-term range and
   required/all-material views.
8. **Aggregation (`4_merged_records.sql`).** Build `section_cost`, materialized
   `master_section`, and views `master_course`, `master_course_material`, and the
   Fall 2025 BMG scope projection. Enrichment belongs on `master_section`; downstream
   views filter/project it rather than re-deriving columns.
9. **Release rollups (`scripts/sql/models/`).** The runner materializes the canonical bare
   SELECTs as `master_institution` and `master_isbn`. Export wrappers and Metabase Models
   select these tables rather than carrying independent copies of their aggregation logic.

## 3. Table/data dictionary (contract grains)

The following is the release-facing grain dictionary. Types and complete columns are
authoritative in [`schema.dbml`](schema.dbml); common values/formats below are the
values used by current SQL.

| Table/view | Grain / key | Key fields (type; common values or format) | Upstream source / intended analysis |
|---|---|---|---|
| `course_catalog_20251215` | one source catalog row | `unit_id` INTEGER; `period_sortable` `YYYY-N`; `course_id`, `section_id` VARCHAR | BMG DiscoveryExtract; adoption and coverage denominators |
| `ipeds_data` | one institution (`unitid`) | `sector`, `iclevel`, `control`, `instsize` VARCHAR descriptors; enrollment INTEGER | IPEDS snapshot; institution stratification |
| `opt_out` / `panel` | one cleaned email per source row | `email` VARCHAR lowercase/trimmed; response year VARCHAR | BVA/CMM mailing enrichment and exclusions |
| `state_region` | one state/province code | `state`, `region`, `division` VARCHAR | Static Census-style geography enrichment and QA reference |
| `format_type_classification` | one FormatType | `is_oer`, `is_ia` BOOLEAN; category VARCHAR | CMM lookup; OER/IA classification |
| `supply_isbn_classification` | one classified ISBN | `isbn13` VARCHAR; category VARCHAR | CMM keyword lookup; supply audit |
| `section_book_status` | one `section_id` | `has_required` BOOLEAN | Catalog + supply classification; required inference |
| `comprehensive_data` | catalog/adoption row | source catalog fields plus `is_oer`, `is_ia`, `is_supply`, `is_required_inferred` BOOLEAN | Catalog × IPEDS × email × FormatType × section status; master fact source |
| `pricing_historical` | `(section_id, isbn13, book_option, book_condition, book_format, rental_days)` | option `buy`/`rental`; condition `new`/`used`/NULL; format `physical`/`digital`/NULL; price DECIMAL | BVA pricing snapshot after dedupe; per-term price analysis |
| `pricing_wide` / `pricing_wide_filtered` | one `(section_id, isbn13)`; filtered view is inferred-required | 18 option/condition/format price cells; `format_count`, `price_min/max`, `rental_days_min/max`; filtered `is_required_inferred=TRUE` | Pricing history + catalog enrichment; material-price analysis |
| `section_cost` | one `section_id` (2024+) | required/optional total and buy-only bounds; priced counts | `comprehensive_data` × `pricing_wide`; section cost coverage |
| `master_section` | one `section_id` (2024+) | counts, OER/IA, supply audit, coverage, enrollment fill, costs | Catalog + section cost; primary section-level analysis |
| `master_course` | one `(course_id, period_sortable)` | section/material/enrollment rollups; course cost rollup | `master_section`/`section_cost`; course-level analysis |
| `master_course_material` | course-period-publisher-status group | material instances, sections using, seats affected | `comprehensive_data` (supplies excluded); publisher/material distribution |
| `master_section_us_intro_fall2025` | one selected `section_id` | Fall 2025, required-bearing, US intro/intermediate sections | Filtered `master_section`; BMG initial-analysis surface |
| `master_institution` | one `(period_sortable, unit_id)` | 36 institution/section-coverage fields; NULL unit is an explicit unknown bucket | `master_section` × `section_book_status` plus `pricing_wide` URL; institution-term release and Metabase model |
| `master_isbn` | one `(period_sortable, isbn13)` | 44 metadata, DQ, coverage, price-cell, and institution-type fields | Distinct catalog section×ISBN spine × `master_section` × `pricing_wide`; ISBN-term release and Metabase model |
| `master_mailing`, `recent_periods`, `current_mailing`, state views | unique cleaned email / latest-period selector / filtered views | most recent period; state views include CA/TX/FL/NY/other | Catalog + opt-out/panel; mailing outputs |
| `__data_quality_metrics` and six `__data_quality_*` drill-down tables | metric row or named top-N/distribution grain | counts for catalog, pricing, joins, ISBN, and wide-pivot checks | Snapshot DQ surfaces created by `2d_data_quality.sql`; diagnostic, not analysis facts |

`email_issues.tsv` is a file audit emitted during import, not a persistent DuckDB table.
The optional legacy `5_univariate_summaries.sql` and `6_crosstab_summaries.sql` files are not
in `run_sql.sh` and therefore are not part of the canonical pipeline above.

## 4. Selection, inclusion, and exclusion rules

- `section_id` is `unit_id::dept_code::course_number::section::period_sortable`; the
  period is part of the key. `course_id` omits section and period. A section means one
  section offering in one period, not a cross-period course.
- `master_section`, `section_cost`, and `master_course_material` include rows with
  `period_date >= '2024-01-01'`, non-null `section_id`, and non-null
  `period_sortable`, as implemented in [`scripts/sql/4_merged_records.sql`](scripts/sql/4_merged_records.sql#L14).
- Blank ISBN is an empty/NULL source value and is retained in catalog coverage counts;
  cost aggregation requires non-null ISBN and therefore excludes no-ISBN rows from
  priced-material cost totals. Do not silently treat no ISBN as no adoption.
- Supplies are retained for audit (`is_supply`, `supply_count`) but excluded from all
  master material counts, OER/IA counts, publisher lists, and section/course cost sums.
  The classifier is precision-oriented and keyword-bounded; it is not an exhaustive
  supply census.
- Required classification is `is_required_inferred`: for 2024+, a `required` row when
  the section has a non-supply required item, otherwise a NULL-status fallback when it
  does not. Raw `book_status` remains available and is not overwritten.
- The BMG Set A/B release scope is course level in introductory/general undergraduate,
  intermediate undergraduate, non-degree credit, or uncategorized, and sector in the
  six real teaching-sector descriptors listed in [`HANDOFF.md`](HANDOFF.md). Set A is
  `required_count >= 1`; Set B is `required_count = 0`; their section totals must be
  reported together and reconcile to the same scope denominator.
- The named Fall 2025 US intro/intermediate view further selects
  `period_sortable='2025-4'`, `required_count >= 1`, the two intro/intermediate levels,
  and `state NOT IN ('CAN','')`; it is a filtered projection in
  [`scripts/sql/4_merged_records.sql`](scripts/sql/4_merged_records.sql#L364).
- `master_institution` retains every 2024+ `master_section` row. Sections without `unit_id`
  roll into one explicitly documented unknown-institution row per term; they receive no
  bookstore URL. The canonical URL is the most frequent nonblank URL among that unit's
  priced section-material rows in the same encoded term, with lexical tie-breaking.
- `master_isbn` retains 2024+ rows with a nonblank ISBN and excludes ISBNs classified as
  supplies. Canada and unknown-state rows remain because this request did not specify a
  geography exclusion. Catalog duplicates collapse before price and enrollment joins;
  canonical metadata is lexical `MIN`, while variant counts and `metadata_conflict` retain DQ.
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
| `has_isbn`, `has_formattype` | Section coverage flags over non-supply materials; accompanying numerators are `isbn_count` and `classified_count`. |
| `enrollment_assigned`, `enrollment_source` | Raw enrollment first, usable `seats_taken < 9999`, sibling enrollment, sibling seats, control×level median, level median; source is `own`, `own_seats`, `sibling_enroll`, `sibling_seats`, `class_median`, `level_median`, or `none`. Raw values remain unchanged. Medians are per period over the four BMG levels × six teaching sectors. |
| `price_min`, `price_max` | Bounds over valid prices for a section/ISBN; prices `>= 9999` are nulled as sentinels. |
| `price_avg` and `*_cost_avg` | Legacy midpoint `(min + max) / 2.0`, not an arithmetic mean. Label this explicitly in every release/export. |
| `*_cost_total_*` | Sum of per-ISBN bounds over distinct priced, non-supply materials, split by `is_required_inferred`. |
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

1. **Catalog coverage:** denominator = catalog rows or distinct `section_id`s, as
   labelled; `has_isbn` and `has_formattype` numerators are section material counts
   over non-supplies. The catalog includes no-ISBN rows.
2. **Pricing coverage:** denominator = distinct `(section_id, ISBN13)` course-material
   keys in the selected catalog slice; numerator = `required_priced_count` or
   `optional_priced_count` (a valid `price_min` exists). Report total-price and
   buy-only coverage separately; do not use `has_buy` alone as a valid-price flag.
3. **Section cost:** denominator = all selected `master_section` sections, including
   sections with no priced material; NULL cost means no valid bound, not zero cost.
4. **OER/IA:** denominator = non-supply course-material items/sections in the named
   slice; `has_formattype` is the classifiability denominator and `is_oer`/`is_ia` are
   not silently recoded from NULL to false at the raw-material level.
5. **Enrollment-weighted results:** denominator/weight must name whether the result
   uses `enrollment_assigned` or raw enrollment and report `enrollment_source` mix;
   imputed enrollment is not equivalent to observed enrollment.
6. **Master Institution counts:** every `*_section_count` denominator is the distinct
   `master_section` rows for that term×unit. `required_section_count` is the supply-aware
   raw required flag; `inferred_required_section_count` is `required_count > 0`.
   Required/optional priced names follow their actual statuses, correcting the reversed
   stakeholder prose. Enrollment totals use `enrollment_assigned`; valid-seat totals omit 9999.
7. **Master ISBN counts:** distinct-key and enrollment counts use the deduplicated
   section×ISBN spine. Every `price_*_count` counts sections with a non-NULL wide price cell,
   so rental terms and repeated catalog listings cannot multiply it. Institution-type counts
   likewise count distinct sections, not raw catalog or pricing rows.

The full release uses all rows meeting the stated scope. The reproducible sample export
is not a random per-query draw: [`scripts/sql/exports/34_master_section_sample10pct.sql`](scripts/sql/exports/34_master_section_sample10pct.sql)
selects one row per `section_id` where `hash(section_id) % 10 = 0`, giving an approximately
10% deterministic partition. It must not be expected to equal exactly one tenth in
every subgroup; compare sample results to the same denominator definitions before
extrapolating.

The combined canonical tables retain `period_sortable`; `scripts/export_cmm_masters.sh`
splits them without changing filters or calculations into one release-dated CSV per priced
term. `scripts/sql/exports/35_master_institution_by_term.sql` and
`36_master_isbn_by_term.sql` provide combined all-term exports from those same tables.

## 7. Known pending Spring 2026 inputs and unresolved decisions

The August update notes say that two additional terms of course data are available,
but do not identify checked-in filenames or certify that they have been loaded. The
following are expected or planned, not current pipeline facts: Spring 2026 BMG course
materials; 25 institution IPEDS IDs; two additional-term institution pricing
(`bva_ipeds_sample25`); BVA mailing-history update; an external Amazon/other pricing
snapshot (`cmm_external_pricing_YYYYMMDD`); discipline lookup (`cmm_discipline`); and
later campus-level inclusive-access data (`cmm_ia`). See [`comms/26-08-17.md`](comms/26-08-17.md).

Before a Spring 2026 release, confirm source filenames/snapshot dates, institution-ID
coverage, pricing-to-catalog key normalization, discipline join key, bookstore URL
availability, and whether the same 2024+ and supply/required rules apply. The current
SQL does not yet implement a separate `no_details` or `no_materials` exclusion flag;
those names appear in the processing proposal, so their definition and use must be
resolved before they affect denominators. `#26` (whether “owned cost” covers all
required materials or only the buy-priced subset and how to label it) remains a PI
decision, as recorded in [`BMG-SUMMARY.md`](BMG-SUMMARY.md). Do not present these as
implemented transformations until the authoritative SQL and schema are updated.

## Evidence and change control

This contract is grounded in [`SCHEMA.md`](SCHEMA.md), [`schema.dbml`](schema.dbml),
[`HANDOFF.md`](HANDOFF.md), [`CLAUDE.md`](CLAUDE.md), [`README.md`](README.md),
[`BMG-SUMMARY.md`](BMG-SUMMARY.md), the August communications
([`26-08-05.md`](comms/26-08-05.md), [`26-08-14.md`](comms/26-08-14.md),
[`26-08-17.md`](comms/26-08-17.md)), and the executable SQL paths linked above.
When this document and SQL disagree, treat the SQL output and the authoritative schema
as the contract and record the discrepancy for correction; do not patch a release by
silently changing a denominator.
