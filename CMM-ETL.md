---
notion-id: 3cbd9fdd-1a1a-81d8-93ef-fd579a76812b
notion-url: https://app.notion.com/p/CMM-ETL-Contract-3cbd9fdd1a1a81d893effd579a76812b
notion-sync: push
---

# Course Material Monitor (CMM) ETL contract

This is the canonical release-facing contract for the implemented DuckDB pipeline. SQL controls
executable behavior; [`schema.dbml`](schema.dbml) controls machine-readable definitions. See
[`SCHEMA.md`](SCHEMA.md) for lineage and exports, [`DATA-DICTIONARY.md`](DATA-DICTIONARY.md) for
relations and columns, and [`DASHBOARDS-REPORTS.md`](DASHBOARDS-REPORTS.md) for reporting surfaces.

## 1. Authority, ownership, and source snapshot

- BMG owns course-material and raw bookstore pricing/cost observations.
- BVA owns opt-out and mailing-history inputs.
- IPEDS owns institution metadata.
- Project-authored classifications and derived outputs are internal. Existing executable table
  names are compatibility names, not source-prefix claims.

| Recorded source | Imported relation | Purpose |
|---|---|---|
| `DiscoveryExtract.20251215.csv` | `course_catalog_20251215` | BMG catalog/adoptions |
| `IPEDS_2024.csv` | `ipeds_data` | institution attributes |
| `OptOut_20251215.csv` | `opt_out` | BVA exclusions; retained source rows with normalized email (not guaranteed one row per email) |
| `panel_20260108.csv` | `panel` | existing BVA response history |
| `format_type_lookup.tsv` | `format_type_classification` | OER/IA lookup |
| `BookPricing.Historical_20260224.csv` | `pricing_historical` | BMG pricing observations |
| `supply_keywords.tsv` | `supply_isbn_classification` | internal supply classifier |

A release records the actual filenames and snapshot dates, pipeline commit, and configuration.
This repository does not assert that pending Spring 2026 inputs have been loaded.

## 2. Execution order and semantics

`scripts/run_sql.sh` envsubst-templates all SQL and rebuilds selected relations. With no skip flags,
it executes the following order:

| Stage | SQL | Contract |
|---|---|---|
| Import | `0_setup.sql` | Normalize catalog, email, enrollment, period, and IDs; import IPEDS, opt-out, and panel. Preserve `panel` source rows and build one-row-per-email `panel_email`. The recorded snapshot is count-preserving, but raw `opt_out`/`ipeds_data` joins do not enforce unique lookup keys; each refresh must prove lookup-key uniqueness and source-row conservation. |
| Import | `0b_state_region.sql` | Build the state/region lookup; `CAN` maps to `Other`. Canonical facts are not materialized with these fields. |
| Import | `1_bookprices_import.sql` | Parse pricing and IDs. Collapse byte-identical rows, rows differing only by instructor, then keep the latest `pricing_date` at the natural pricing key; aggregate instructor names. |
| Import | `1a_supply_classification.sql` | Classify 2024+ ISBNs from title include/exclude keywords. Blank/unmatched ISBNs are not supplies; attribution is deterministic. |
| Import | `1b_section_filter.sql` | Build one `section_book_status` row per catalog `section_id`; `has_required` is any required, non-supply item. |
| Import | `2_oer_classification.sql` | Rebuild `comprehensive_data` at normalized BMG source-row grain with IPEDS, lookup, panel, opt-out, required, and population flags. |
| Import | `2b_course_materials.sql` | Build the full 2024+ `section_enrollment` spine and canonical `course_materials` plus population views. See [`COURSE-MATERIAL-POPULATIONS.md`](COURSE-MATERIAL-POPULATIONS.md). |
| Import | `2c_pricing_wide.sql` | Pivot pricing to one `(section_id, isbn13)` row with 18 price cells, option/bounds fields, and rental-term bounds. |
| Import | `2d_data_quality.sql` | Materialize import-state metrics and drill-downs, including non-mutating exact pricing/catalog comparisons. These are diagnostics, not release denominators. |
| EDA | `3_mailing_lists.sql` | Build Master, Working, and geographic mailing relations. See [`MAILING-FLOW.md`](MAILING-FLOW.md). |
| EDA | `3b_material_costs.sql` | LEFT-enrich every canonical Use item from `pricing_wide` on exact section × ISBN. See [`PRICING-CATALOG-MATCHING.md`](PRICING-CATALOG-MATCHING.md). |
| EDA | `4_merged_records.sql` | Build `section_cost`, `master_section`, `master_course`, `master_course_material`, and the Fall 2025 compatibility projection. |
| Models | `scripts/sql/models/*.sql` | Materialize discovered models, including `master_institution`, `master_isbn`, and `sample10_section_ids`. |
| Exports | `scripts/sql/exports/*.sql` | Unless `NO_EXPORT` is set, execute discovered wrappers in lexical order and write `output/<basename>.csv`. Standalone per-term and Parquet exporters are separate commands. |

The pipeline is DROP/recreate and re-runnable. Exact file and output topology is in
[`SCHEMA.md`](SCHEMA.md#operational-stages).

## 3. Canonical grains and lineage

| Relation | Grain | Contract |
|---|---|---|
| `course_catalog_20251215` | one normalized catalog source row | BMG source denominator. |
| `comprehensive_data` | exactly one enriched normalized catalog row | The recorded snapshot is one row per normalized catalog row and count-preserving. SQL directly joins raw `opt_out` and `ipeds_data` without enforcing or collapsing duplicate lookup keys, so refresh DQ must prove lookup-key uniqueness and row-count conservation. |
| `section_enrollment` | one `(period_sortable, section_id)` for valid 2024+ sections | Owns complete section/enrollment denominators and assignment. Independent of material inclusion. |
| `course_materials` | one `(period_sortable, section_id, isbn13)` | First canonical processed table; NULL ISBN is a single audit row per section when present. Keeps duplicate, variant, conflict, and population evidence. |
| `pricing_historical` | one `(section_id, isbn13, book_option, book_condition, book_format, rental_days)` | Source-owned latest pricing observation after defined dedupe. |
| `pricing_wide` | one `(section_id, isbn13)` | Source-owned pricing pivot; no catalog, IPEDS, OER/IA, or required-inference enrichment. |
| `material_costs` | one canonical Use `(period_sortable, section_id, isbn13)` | Catalog-owned item spine LEFT-enriched from `pricing_wide`; unmatched and unpriced items remain. |
| `section_cost` | one material-bearing `(period_sortable, section_id)` | Cost bounds aggregated from `material_costs`. |
| `master_section` | one section represented in `material_costs` | Material-bearing release spine. Section dimensions/enrollment come from `section_enrollment`; price/cost fields come from `section_cost`. |
| `master_course` | one `(course_id, period_sortable)` | Course rollup of material-bearing sections. |
| `master_course_material` | one exact group `(course_id, period, period_sortable, period_date, school, department, course_number, course_title, publisher, book_status)` | Material distribution from `material_costs`, filtering NULL `course_id`, `publisher`, and `period_sortable`. |
| `master_institution` | one `(period_sortable, unit_id)`, including NULL unit bucket | Institution rollup of `master_section`; bookstore URL is the documented same-term pricing exception. |
| `master_isbn` | one `(period_sortable, isbn13)` | ISBN rollup of canonical Use items in `material_costs`. |

`section_id` is period-specific:

```text
unit_id::dept_code::course_number::section::period_sortable
```

`course_id` omits section and period. Missing composite segments become `UNKNOWN`; those component
values are not an admission filter. Canonical admission requires non-NULL `period_sortable` and
`section_id`, so rows with UNKNOWN components can remain while rows missing either admission key
remain only in `comprehensive_data` and DQ counts them.
`period_sortable` maps Winter/Spring/Summer/Fall to `YYYY-1/2/3/4`; `period_date` maps them to
January 1, April 1, July 1, and October 1.

## 4. Population, selection, and enrollment rules

The authoritative row and canonical-item predicates are detailed in
[`COURSE-MATERIAL-POPULATIONS.md`](COURSE-MATERIAL-POPULATIONS.md). In summary:

- Use is 2024+, non-Canada, non-NULL ISBN, non-supply, not `*No Book Details*`, and not
  no-material (`*No Books Required*` or `supply_category='placeholder_no_material'`).
- NoUse is the exact post-2024 complement. Use and NoUse are both false before 2024. Canada is a
  separately exposed subset of NoUse. Exclusion flags may overlap; do not replace them with a
  single reason.
- `material_costs` preserves every canonical Use item. `master_section` contains exactly sections
  with at least one such item; it is not the complete section denominator.
- Required inference is true for 2024+ catalog rows when a section with any non-supply required
  item has `book_status='required'`, or when a section without one has NULL `book_status`. Raw
  pricing `book_status` and `required` remain source-owned and are not overwritten.
- The Fall 2025 BMG Set A/B scope uses the four levels introductory/general undergraduate,
  intermediate undergraduate, non-degree credit, and uncategorized, and the six public/private
  nonprofit/private for-profit × two-/four-year sector labels. Set A has `required_count >= 1`;
  Set B has `required_count = 0` and is optional-only, not no-adoption.
- `master_section_us_intro_fall2025` further requires `period_sortable='2025-4'`,
  `required_count >= 1`, either introductory or intermediate level, and
  `state NOT IN ('CAN','')`. NULL state is excluded. This is a non-Canada/nonblank proxy, not a
  validated country test.

`section_enrollment` uses the full valid 2024+ section spine. Assignment precedence is:

1. own enrollment;
2. own `seats_taken < 9999`;
3. course × period median enrollment;
4. course × period median usable seats;
5. control × level × period median enrollment;
6. level × period median enrollment;
7. otherwise NULL with source `none`.

Medians use the four BMG course levels and exact six-sector reference population above and are
rounded to integers. `enrollment_source` is `own`, `own_seats`, `sibling_enroll`,
`sibling_seats`, `class_median`, `level_median`, or `none`; raw values remain available.

## 5. Pricing and cost semantics

`material_costs` joins:

```sql
FROM course_materials_use cm
LEFT JOIN pricing_wide pw
  ON cm.section_id = pw.section_id
 AND CAST(cm.isbn13 AS VARCHAR) = pw.isbn13
```

This exact match is incomplete and intentionally unchanged. The evidence, alternatives, and
release gates are in [`PRICING-CATALOG-MATCHING.md`](PRICING-CATALOG-MATCHING.md); any broader
matching strategy is unimplemented.

| Field | Meaning |
|---|---|
| `format_count` | Distinct offered option × condition × format tuples for buy/rental, regardless of price validity. |
| `has_buy`, `has_rent` | Option presence, not proof of a valid price. |
| `price_min`, `price_max` | Bounds across valid prices; values `>= 9999` are treated as sentinels and nulled. |
| `price_avg` | Item-level legacy midpoint `(price_min + price_max) / 2.0`, not arithmetic mean; the same item midpoint is carried into `material_costs`. |
| `*_cost_avg` on `master_section` | Section-level midpoint `(section min + section max) / 2.0`, not an item average. |
| `*_cost_avg` on `master_course` | Arithmetic `AVG` of the corresponding section midpoints across the course's sections; it is not the midpoint of course-level bounds. |
| `*_cost_total_*` | Sums of per-ISBN bounds across priced Use items, split by inferred required status. |
| `*_cost_owned_*` | Buy-only bounds; rental-only items may have total-price coverage but NULL owned cost. |
| `rental_days_min/max` | Rental-term range. Wide cells use `MAX(price)` across terms; use `pricing_historical` for per-term analysis. |
| `has_pricing_match` | Exact section × ISBN pricing row exists. It does not imply any valid price cell. |

## 6. NULL, dedupe, and DQ invariants

- NULL IPEDS fields mean no matched institution metadata; they are not zeros or categories.
- NULL OER/IA means FormatType was absent/unclassifiable; do not silently recode it to false when
  reporting classification rates.
- NULL pricing fields in `material_costs` mean no matched value or valid price. Distinguish no
  exact match (`has_pricing_match=FALSE`) from a matched row with NULL price cells. Neither means
  zero cost.
- NULL cost on `master_section` means no valid bound, not zero cost or no adoption.
- Catalog canonicalization uses a deterministic representative. Counts and conflict flags retain
  title, author, publisher, imprint, format, FormatType, status, contact, and population
  disagreements; canonical catalog metadata never comes from pricing.
- Pricing dedupe follows the three import stages in section 2. Rental-term multiplicity is valid
  in `pricing_historical` and collapses only in `pricing_wide`.
- DQ must prove raw-to-canonical conservation, canonical key uniqueness, Use-key conservation,
  Use/NoUse partition validity, geographic mailing reconciliation, and key conservation from
  `course_materials_use` through `material_costs`.

## 7. Denominators and reporting

Every percentage or crosstab states its grain and denominator:

| Analysis | Required denominator |
|---|---|
| Raw catalog coverage | Labeled catalog rows or distinct section IDs from `comprehensive_data`. |
| Complete section/enrollment coverage | `section_enrollment`, including no-ISBN/no-adoption sections. |
| Release item/pricing coverage | Canonical Use keys in `material_costs`; report exact-match and valid-price coverage separately, and total-price versus buy-only coverage separately. |
| Section cost | Selected material-bearing `master_section` rows, including sections with no valid price. |
| OER/IA | Named Use item or material-bearing section slice; report `has_formattype` classifiability. |
| Enrollment weighted | State raw versus `enrollment_assigned` and report the `enrollment_source` mix. |
| Institution | Material-bearing `master_section` rows in each term × unit; NULL unit remains an explicit unknown bucket. |
| ISBN | Deduplicated `material_costs` section × ISBN keys; price-cell counts are distinct sections. |

Metabase must route release-facing item analyses to `material_costs`, release-facing section
analyses to `master_section`, and complete-population diagnostics to `comprehensive_data` or
`section_enrollment` with the broader denominator labeled. The full dashboard/question inventory
is in [`DASHBOARDS-REPORTS.md`](DASHBOARDS-REPORTS.md).

The stable 10% sample is selected from all `section_enrollment` rows by unsigned first-64-bit
MD5 of `section_id` modulo 10, bucket zero (`md5-prefix64-mod10-v1`). Join the single
`sample10_section_ids` membership back to each stage; do not resample per query. Only additive
section-cluster totals may be expanded by ten; distinct institution or ISBN domains may not.

## 8. Pending inputs and change control

The following are boundaries, not current facts: Spring 2026 BMG course materials; the additional
institution/IPEDS input; additional-term BMG pricing; updated BVA mailing history (issue #56);
external pricing; discipline lookup; and later campus-level IA data. The current mailing branch
uses the existing `panel_email` snapshot; see [`MAILING-FLOW.md`](MAILING-FLOW.md). The pricing
table is rebuilt to the latest row per logical key and is not a cross-snapshot history store.

Before using new inputs, record source identity and dates, verify schemas and term mappings, rerun
grain/conservation/coverage checks, and resolve any source-specific join policy. The meaning and
label of owned cost remains an unresolved decision (#26); do not present it as resolved until SQL
and schema change.

When this document disagrees with executable SQL, SQL output and the authoritative schema win.
Record and correct the documentation discrepancy; never silently change a denominator or release
population.

## Detail pages

<page url="https://app.notion.com/p/3ced9fdd1a1a81cf979cc0c82e965b1e">Course-material populations</page>
<page url="https://app.notion.com/p/3ced9fdd1a1a815fae7debf66b76d4ef">Mailing flow</page>
<page url="https://app.notion.com/p/3ced9fdd1a1a818db34ef52788da8997">Pricing-to-catalog matching</page>
