---
notion-id: 3cbd9fdd-1a1a-8086-b499-daa92a739c9f
notion-url: https://app.notion.com/p/sqrlly/Data-Lineage-3cbd9fdd1a1a8086b499daa92a739c9f
notion-sync: push
---

# Schema

## Inputs

Paths are configured in `scripts/dot.env`.

| Owner | Configured input | Loaded target/consumer |
|---|---|---|
| BMG | `DiscoveryExtract.*.csv` | `course_catalog_<date>` |
| BMG | `BookPricing.Historical_*.csv` | `pricing_historical` |
| IPEDS | `IPEDS_2024.csv` | `ipeds_data` |
| BVA | `OptOut_*.csv` | `opt_out` |
| BVA | `panel_*.csv` | `panel_email` |
| Internal | `format_type_lookup.tsv` | `format_type_classification` |
| CMM | `scripts/sql/lookups/supply_keywords.tsv` | supply classification/audit |

## Operational stages

Run `scripts/run_sql.sh`; SQL is rendered with `envsubst`. DROP-before-CREATE makes normal runs re-runnable. `NO_IMPORT`, `NO_EDA`, and `NO_EXPORT` skip stages; `CUSTOM_SQL_FILES` replaces the list.

| Stage | Files | Result |
|---|---|---|
| IMPORT | 11 fixed SQL files | Cleanup, source loading, shared recent terms, normalization/enrichment, canonical materials, pricing pivot, DQ snapshots; `0_setup.sql` also writes `output/email_issues.tsv`. |
| EDA | 3 fixed SQL files | Mailing, Material Costs, and section/course masters. |
| Models | `scripts/sql/models/*.sql` lexical | `master_institution`, `master_isbn`, `sample_material_10pct`. |
| EXPORT | `scripts/sql/exports/*.sql` lexical, top-level | Temporary-table wrappers to `output/<basename>.csv`. |

After IMPORT, mailing export requires `3_mailing_lists.sql`; wrapper-only runs with `NO_IMPORT=1` may use last-refreshed mailing relations.

### Exact `run_sql.sh` order

```mermaid
flowchart TD
  run["scripts/run_sql.sh"] --> i0c["01 · 0_cleanup.sql"]
  run -. "NO_IMPORT" .-> x01["01_sample_records.sql"]
  i0c --> i00["02 · 0_setup.sql"] --> i0b["03 · 0b_state_region.sql"] --> i0r["04 · 0c_recent_period.sql"] --> i10["05 · 1_bookprices_import.sql"] --> i1a["06 · 1a_supply_classification.sql"] --> i1b["07 · 1b_section_enrollment.sql"] --> i20["08 · 2_oer_classification.sql"] --> i2b["09 · 2b_course_material.sql"] --> i2c["10 · 2c_pricing_wide.sql"] --> i2d["11 · 2d_data_quality.sql"]
  i2d --> e30["12 · 3_mailing_lists.sql"] --> e3b["13 · 3b_master_material.sql"] --> e40["14 · 4_merged_records.sql"] --> m01["15 · models/master_institution.sql"] --> m02["16 · models/master_isbn.sql"] --> m03["17 · models/sample_material_10pct.sql"] --> x01
  i2d -. "NO_EDA" .-> x01
  x01 --> x10["10_master_mailing.sql"] --> x11c["11_current_mailing.sql"] --> x11r["11_recent_mailing.sql"] --> x20["20_california_mailing.sql"] --> x21["21_texas_mailing.sql"] --> x22["22_florida_mailing.sql"] --> x23["23_newyork_mailing.sql"] --> x24["24_texas_fall_series.sql"] --> x25["25_pennsylvania_mailing.sql"] --> x26["26_canada_mailing.sql"] --> x27["27_other_mailing.sql"] --> x30["30_faculty_records.sql"] --> x31["31_master_section.sql"] --> x32["32_master_course.sql"] --> x34["34_sample_material_10pct.sql"] --> x35["35_master_institution_by_term.sql"] --> x36["36_master_isbn_by_term.sql"] --> x37["37_sample10_reconciliation.sql"] --> x38["38_cmm_release_reconciliation.sql"] --> x39["39_cmm_release_key_reconciliation.sql"] --> x40["40_master_material_by_term.sql"] --> x41["41_master_material_reconciliation.sql"]
```

## Relation inventory

| Relation | Grain / role |
|---|---|
| `course_catalog_<date>` | Normalized BMG source rows. |
| `ipeds_data` | Institution lookup. |
| `opt_out` | Normalized-email BVA rows; duplicates allowed. |
| `panel_email` | BVA response history grouped to one row/email. |
| `state_region` | Catalog-state-code-to-region lookup. |
| `format_type_classification` | FormatType-to-OER/IA lookup. |
| `supply_isbn_classification` | One classified recent-term ISBN row. |
| `comprehensive_data` | One enriched normalized catalog row; refresh DQ proves lookup uniqueness/count preservation. |
| `section_enrollment` | One valid recent-term period×section; catalog-only enrollment/seats and sibling signals. |
| `course_material` | One period×section×ISBN plus at most one NULL-ISBN audit row. |
| `course_material_recent` | Recent-term projection. |
| `course_material_use` | Use projection. |
| `course_material_no_use` | Exact recent-term complement. |
| `pricing_historical` | Section×ISBN×option×condition×format×rental-term pricing. |
| `pricing_wide` | One section×ISBN; provenance and 18 price cells. |
| `__data_quality_*` | Non-mutating DQ snapshots. |
| `master_mailing` | One nonblank cleaned email before history/opt-out. |
| `recent_period` | Lookup view of newest 12 non-NULL terms from `course_catalog_20251215`. |
| `current_mailing` | Eligible cleaned email after recency/history/opt-out. |
| `master_material` | One canonical Use period×section×ISBN; LEFT pricing enrichment. |
| `master_section` | One material-bearing period×section. |
| `master_course` | Provisional period×course release; definition pending. |
| `sample_section_us_intro_fall2025` | Fall-2025 required intro/intermediate section sample. |
| `master_institution` | Provisional period×institution release, including NULL unit; definition pending. |
| `master_isbn` | Canonical Use period×ISBN rollup. |
| `sample_material_10pct` | Sampled `master_material` rows for selected sections. |

## Data dependencies

Solid arrows are implemented dependencies; dashed masters await final definitions. All 32 DBML relations are consumed by the staged SQL. Geographic mailing is seven direct `current_mailing` export filters; Canada material exports filter `course_material_no_use` directly.

```mermaid
flowchart TD
  course_catalog_20251215 --> supply_isbn_classification
  course_catalog_20251215 --> section_enrollment --> comprehensive_data
  course_catalog_20251215 --> comprehensive_data
  supply_isbn_classification --> comprehensive_data
  ipeds_data --> comprehensive_data
  opt_out --> comprehensive_data
  panel_email --> comprehensive_data
  format_type_classification --> comprehensive_data
  comprehensive_data --> course_material
  course_material --> course_material_recent
  recent_period --> course_material_recent
  recent_period --> supply_isbn_classification
  recent_period --> section_enrollment
  recent_period --> comprehensive_data
  course_material_recent --> course_material_use
  course_material_recent --> course_material_no_use
  pricing_historical --> pricing_wide
  course_material_use --> master_material
  pricing_wide --> master_material
  master_material --> master_section
  master_section -.-> master_course
  master_section --> sample_section_us_intro_fall2025
  master_section -.-> master_institution
  master_material --> master_isbn
  master_material --> sample_material_10pct
  course_catalog_20251215 --> master_mailing
  master_mailing --> current_mailing
  course_catalog_20251215 --> recent_period --> current_mailing
  panel_email --> current_mailing
  opt_out --> current_mailing
  comprehensive_data --> __data_quality_metrics
  pricing_historical --> __data_quality_metrics
  pricing_wide --> __data_quality_metrics
  pricing_csv["${PRICING_CSV}"] --> __data_quality_metrics
  comprehensive_data --> __data_quality_top_unmatched_ipeds_schools
  comprehensive_data --> __data_quality_null_isbn_breakdown
  comprehensive_data --> __data_quality_top_null_isbn_schools
  pricing_historical --> __data_quality_pricing_match_by_period
  comprehensive_data --> __data_quality_pricing_match_by_period
  pricing_historical --> __data_quality_top_unmatched_pricing_sections
  comprehensive_data --> __data_quality_top_unmatched_pricing_sections
  pricing_wide --> __data_quality_format_count_distribution
  classDef provisional stroke:#777,stroke-dasharray:6 4;
  class master_course,master_institution provisional;
```

`state_region` is an IMPORT lookup joined at query time. There are 32 DBML relations
(25 tables, seven views). `section_enrollment` uses catalog data and the recent-term window; IPEDS-scoped
medians and requiredness are computed inside `comprehensive_data`. Dashed masters
have executable draft SQL but await final definitions.

## Export dependencies and inventory

Normal EXPORT runs 23 top-level wrappers, lexically, each to `output/<basename>.csv`: `01_sample_records`; `10_master_mailing`; `11_current_mailing`, `11_recent_mailing`; `20`–`27` mailing filters; `30_faculty_records`; `31`, `32`, `34`–`36` release/model exports; `37`–`39` reconciliations; `40_master_material_by_term`; `41_master_material_reconciliation`. Wrapper 1 is unseeded raw sampling and unrelated to the stable `sample_material_10pct` sample.

`30_faculty_records.csv` requires non-NULL instructor, course number, section, and title.
It groups by faculty ID/instructor/school/email/department, listing record/section counts by term.
Faculty ID uses email, falling back to instructor + school.

| Command | Artifacts |
|---|---|
| `scripts/export_cmm_masters.sh [terms…]` | Four per-term CSVs: `master_section`, `master_institution`, `master_isbn`, `master_material`. |
| `scripts/export_course_material.sh [YYYYMMDD] [YYYY-N]` | Five course-material CSVs; term optional; refuses overwrite. |
| `scripts/export_fall2025_subsets.sh` | Two Fall 2025 Parquet subsets. |
| `scripts/classify_supplies.sh` | `output/fall2025_supply_isbns.parquet`; separate supply audit. |
| `scripts/export_all.sh` | Alternate CSV runner for 23 wrappers. |
| `scripts/export_all_parquet.sh` | Same 23 top-level wrappers → `<basename-without-number>.parquet`; no recursive discovery. |

## Pending inputs and non-current paths

Spring 2026 catalog/pricing, updated IPEDS, external pricing, discipline, updated mailing history, campus IA, bookstore-brand, and the 25 institution list have no SQL nodes until files, grains, keys, and semantics are validated (issues #23, #51, #52, #56, #57, #60, #72). Keep History is not implemented. Pricing import rebuilds `pricing_historical` and retains the latest logical-key row within the configured snapshot; matching is exact and non-mutating. Current baselines describe loaded data only.

<page url="https://app.notion.com/p/3cbd9fdd1a1a81d893effd579a76812b">CMM ETL Contract</page>
