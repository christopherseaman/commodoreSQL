---
notion-id: 3cbd9fdd-1a1a-81d8-93ef-fd579a76812b
notion-url: https://app.notion.com/p/CMM-ETL-Contract-3cbd9fdd1a1a81d893effd579a76812b
notion-sync: push
---

# Course Material Monitor (CMM) ETL contract

## Authority and snapshot

- BMG owns course-material and raw bookstore pricing/cost observations; BVA owns opt-out and mailing-history inputs; IPEDS owns institution metadata.
- Derived outputs are internal; supply rules are CMM-owned. Executable source-table names are compatibility names, not source-prefix claims.

| Recorded source | Target / consumer | Purpose |
|---|---|---|
| `DiscoveryExtract.20251215.csv` | `course_catalog_20251215` | BMG catalog/adoptions |
| `IPEDS_2024.csv` | `ipeds_data` | Institution attributes |
| `OptOut_20251215.csv` | `opt_out` | BVA exclusions; normalized-email source rows (duplicates allowed) |
| `panel_20260108.csv` | `panel` | BVA response history |
| `format_type_lookup.tsv` | `format_type_classification` | OER/IA lookup |
| `BookPricing.Historical_20260224.csv` | `pricing_historical` | BMG pricing observations |
| `supply_keywords.tsv` + catalog titles | `supply_isbn_classification` | Classify ISBNs using CMM-owned title rules |

Releases record filenames, snapshot dates, pipeline commit, and configuration. Spring 2026 inputs are not asserted as loaded.

- Current external sources: BMG materials/pricing, IPEDS, BVA opt-out, and BVA mailing history.
- Pending: CMM IA, external pricing, discipline, Fall 2025 bookstore-brand, and the 25 institution list.
- Keep History is a behavior decision, not a source table.

## Execution and stages

`scripts/run_sql.sh` renders SQL with `envsubst` and DROP/recreates selected relations. Without skip flags:

| Stage | SQL | Contract |
|---|---|---|
| Import | `0_cleanup.sql` | Remove exact retired/report relations and obsolete geographic projections; fail if targets remain. |
| Import | `0_setup.sql` | Normalize catalog, email, enrollment, period, and IDs; import IPEDS/opt-out/panel; preserve `panel`, build one-row-per-email `panel_email`. Refresh DQ must prove lookup-key uniqueness and source-row conservation because raw opt-out/IPEDS joins do not enforce unique keys. |
| Import | `0b_state_region.sql` | Build lookup; `CAN` maps to `Other`; facts are not materialized with region fields. |
| Import | `1_bookprices_import.sql` | Deduplicate byte-identical and instructor-only variants; retain latest `pricing_date` at natural key and aggregate instructors. |
| Import | `1a_supply_classification.sql` | Classify 2024+ ISBNs by title keywords; blank/unmatched ISBNs are not supplies. |
| Import | `1b_section_enrollment.sql` | Build valid 2024+ `section_enrollment` with the established IPEDS-scoped enrollment assignment ladder. |
| Import | `2_oer_classification.sql` | Rebuild `comprehensive_data` at normalized BMG row grain with IPEDS, lookup, panel, opt-out, required, and population flags. |
| Import | `2b_course_material.sql` | Build canonical `course_material` and population views from enriched source rows. |
| Import | `2c_pricing_wide.sql` | Pivot to one `(section_id,isbn13)` row with 18 price cells and rental bounds. |
| Import | `2d_data_quality.sql` | Materialize import-state metrics/drill-downs and non-mutating pricing/catalog comparisons; diagnostics are not release denominators. |
| EDA | `3_mailing_lists.sql` | Build Master, catalog-derived 12-term lookup, and Working; seven geographic exports filter `current_mailing`. |
| EDA | `3b_master_material.sql` | LEFT-enrich every canonical Use item from `pricing_wide` on exact section × ISBN. |
| EDA | `4_merged_records.sql` | Build `master_section`, `master_course`, and `sample_section_us_intro_fall2025`. |
| Models | `scripts/sql/models/*.sql` | Materialize `master_institution`, `master_isbn`, and `sample_material_10pct`. |
| Exports | `scripts/sql/exports/*.sql` | Unless `NO_EXPORT`, run lexical wrappers to `output/<basename>.csv`; standalone exporters are separate. |

The intended database has 33 DBML-managed relations (26 tables, seven views): 24 executable-flow relations, seven DQ sidecars, and two report/export views. Retired relations are removed by cleanup.

## Grains and lineage

| Relation | Grain / contract |
|---|---|
| `course_catalog_20251215` | One normalized BMG source row; source denominator. |
| `comprehensive_data` | One enriched normalized catalog row; snapshot is count-preserving, but refresh DQ must prove raw lookup uniqueness/conservation. |
| `section_enrollment` | One `(period_sortable,section_id)` for valid 2024+ sections; complete section/enrollment denominator, independent of materials. |
| `course_material` | One `(period_sortable,section_id,isbn13)`; one NULL-ISBN audit row per section when present; retains duplicate/variant/conflict/population evidence. |
| `pricing_historical` | One `(section_id,isbn13,book_option,book_condition,book_format,rental_days)`; latest source-owned observation after dedupe. |
| `pricing_wide` | One `(section_id,isbn13)` source-owned pivot; no catalog/IPEDS/OER/IA/required enrichment. |
| `master_material` | One canonical Use `(period_sortable,section_id,isbn13)`; catalog spine LEFT-enriched from pricing; unmatched/unpriced remain. |
| `sample_material_10pct` | Stable 10% section-cluster sample of `master_material`; identical columns and item grain. |
| `master_section` | One section represented in `master_material`; material-bearing section rollup and downstream source. |
| `master_course` | One material-bearing `(course_id,period_sortable)`; `enrollment_total = SUM(master_section.enrollments)` without assigned-value substitution. |
| `master_institution` | One `(period_sortable,unit_id)`, including NULL unit bucket; bookstore URL is same-term pricing exception. |
| `master_isbn` | One `(period_sortable,isbn13)` rollup of canonical Use items. |

`section_id = unit_id::dept_code::course_number::section::period_sortable`; `course_id` omits section and period.

- Missing segments become `UNKNOWN` and do not filter admission.
- Canonical admission requires non-NULL `period_sortable` and `section_id`; rejected rows remain in `comprehensive_data` and DQ.
- `period_sortable` maps Winter/Spring/Summer/Fall to `YYYY-1/2/3/4`; `period_date` maps to Jan/Apr/Jul/Oct 1.

## Population and enrollment

- Use: 2024+, non-Canada, non-NULL ISBN, non-supply, not `*No Book Details*`, and not `*No Books Required*`/`placeholder_no_material`.
- NoUse is the exact post-2024 complement; both flags are false before 2024. Canada exports filter NoUse by `is_canada`; no separate view is stored. Exclusion flags may overlap.
- `master_material` preserves every canonical Use item. `master_section` is material-bearing only, not the complete section denominator.
- `is_required_direct` records literal required, non-supply evidence at row/item grain; `is_section_required_direct` carries section context through finer-grain tables.
- Section directness is grouped inside the `comprehensive_data` build using catalog status and supply classification.
- `is_required_inferred` is true for 2024+ rows when a section has direct required evidence and `book_status='required'`, or has none and `book_status` is NULL. Raw pricing status/required remain source-owned.
- Fall 2025 Set A/B uses four course levels (introductory/general undergraduate, intermediate undergraduate, non-degree credit, uncategorized) and six public/private nonprofit/private for-profit × two-/four-year sector labels. A: `required_count >= 1`; B: `required_count = 0`, optional-only, not no-adoption.
- `sample_section_us_intro_fall2025`: `period_sortable='2025-4'`, `required_count>=1`, introductory/intermediate, and `state NOT IN ('CAN','')`; NULL state excluded. This is a non-Canada/nonblank proxy, not a country test.

`section_enrollment` uses the full valid 2024+ section spine. Assignment precedence:

1. own enrollment
2. own `seats_taken < 9999`
3. course×period median enrollment, then usable seats
4. control×level×period median
5. level×period median
6. otherwise NULL (`none`)

Medians use the four levels and six sectors above, rounded to integers. Sources are `own`,
`own_seats`, `sibling_enroll`, `sibling_seats`, `class_median`, `level_median`, and `none`; raw
values remain.

## Pricing, cost, and NULL semantics

`master_material` LEFT joins `course_material_use` to `pricing_wide` on exact `section_id` and cast `isbn13`; broader matching is unimplemented.

| Field | Meaning |
|---|---|
| `format_count` | Distinct buy/rental option×condition×format tuples, regardless of price validity. |
| `has_buy`, `has_rent` | Option presence, not valid-price proof. |
| `price_min/max` | Bounds across valid prices; `>=9999` sentinels become NULL. |
| `price_avg` | Legacy item midpoint `(min+max)/2`, not arithmetic mean; carried to `master_material`. |
| `*_cost_avg` | Section midpoint; `master_course` uses arithmetic AVG of section midpoints, not course-bound midpoint. |
| `*_cost_total_*` / `*_cost_owned_*` | Per-ISBN bounds across priced Use items / buy-only cells, split by inferred required status. |
| `rental_days_min/max` | Term range; wide cells use `MAX(price)` across terms; use `pricing_historical` per term. |
| `has_pricing_match` | Exact section×ISBN row exists; does not imply a valid price. |

- NULL IPEDS means no matched metadata; NULL OER/IA means absent or unclassifiable FormatType.
- NULL pricing means no match or valid price; distinguish with `has_pricing_match`.
- NULL cost means no valid bound, never zero.
- Catalog representative selection is deterministic; conflict evidence is retained and pricing never supplies catalog metadata.
- Rental multiplicity is valid in historical and collapses only in wide.
- DQ proves raw/canonical conservation, key uniqueness, Use/NoUse partition, mailing reconciliation, and `course_material_use`→`master_material` keys.

## Denominators, samples, and change control

| Analysis | Denominator |
|---|---|
| Raw catalog | Labeled catalog rows or distinct sections in `comprehensive_data`. |
| Complete sections | `section_enrollment`, including no-ISBN/no-adoption. |
| Release item/pricing | Canonical Use keys in `master_material`; separate exact-match, valid-price, total-price, and buy-only coverage. |
| Section cost | Selected material-bearing `master_section`, including unpriced sections. |
| OER/IA | Named Use item or material-bearing section slice; report `has_formattype`. |
| Enrollment weighted | Raw vs `enrollment_assigned` and `enrollment_source` mix. |
| Institution | Material-bearing sections by term×unit; NULL unit is explicit. |
| ISBN | Deduplicated `master_material` section×ISBN; price-cell counts are distinct sections. |

Metabase routes item analyses to `master_material`, section analyses to `master_section`, and complete-population diagnostics to `comprehensive_data`/`section_enrollment`. `sample_material_10pct` keeps sections whose first 64 MD5 bits modulo 10 equal zero (`md5-prefix64-mod10-v1`); reconciliation applies the same rule inline to `section_enrollment`. Only additive section-cluster totals may be expanded.

Pending boundaries: Spring 2026 materials, updated IPEDS, additional-term pricing, BVA history (#56), external pricing, discipline, later campus IA, bookstore-brand, and the 25 institution list.

- Current mailing uses `panel_email`; pricing is latest-per-key within the configured snapshot, not cross-snapshot history.
- New inputs require identity/date, schema and term checks, grain/conservation/coverage validation, and source-specific join policy.
- Owned-cost meaning remains unresolved (#26). SQL and authoritative schema win conflicts; document discrepancies rather than silently changing populations.

## Detail pages

<page url="https://app.notion.com/p/3ced9fdd1a1a81cf979cc0c82e965b1e">Course-material populations</page>
<page url="https://app.notion.com/p/3ced9fdd1a1a815fae7debf66b76d4ef">Mailing flow</page>
<page url="https://app.notion.com/p/3ced9fdd1a1a818db34ef52788da8997">Pricing-to-catalog matching</page>
