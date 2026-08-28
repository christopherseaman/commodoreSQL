# CommodoreSQL Database Schema

DuckDB pipeline integrating course-catalog data (~103M rows) with institutional
characteristics (IPEDS), bookstore pricing, and opt-out/panel lists. Supports targeted
mailing lists and analysis of course-materials cost and OER/Inclusive-Access adoption.

For full column definitions and types see [`schema.dbml`](schema.dbml) (load in dbdiagram.io).
For naming standards and gotchas see [`CLAUDE.md`](CLAUDE.md). For current work status see
[`HANDOFF.md`](HANDOFF.md).

## Source data

| File | Target table | Rows |
|------|-------------|------|
| `DiscoveryExtract.*.csv` | `course_catalog_<date>` | ~103M |
| `IPEDS_2024.csv` | `ipeds_data` | ~7K |
| `OptOut_*.csv` | `opt_out` | variable |
| `panel_*.csv` | `panel` | variable |
| `format_type_lookup.tsv` | `format_type_classification` | ~69 |
| `supply_keywords.tsv` | (read by `1a_supply_classification.sql` + `scripts/classify_supplies.sh`) | 97 incl + 26 excl |
| `BookPricing.Historical_*.csv` | `pricing_historical` | snapshot-dependent (~27.3M current rows) |

## Pipeline

Run via `scripts/run_sql.sh`. Three stages, each skippable by flag
(`NO_IMPORT` / `NO_EDA` / `NO_EXPORT`). DROP-before-CREATE; re-runnable. Config in
`scripts/dot.env`; SQL is envsubst-templated (`${CONFIG}`, `${LOOKUP_DIR}`, …).

### IMPORT stage

| SQL file | Creates | Purpose |
|----------|---------|---------|
| `0_setup.sql` | `course_catalog_*`, `ipeds_data`, `opt_out`, `panel`, `email_issues` | Load CSVs, normalize emails, derive composite keys (`period_date` included) |
| `0b_state_region.sql` | `state_region` | State → region lookup |
| `1_bookprices_import.sql` | `pricing_historical` | Load bookstore pricing; derive `section_id`/period keys; set `required` from Book Status |
| `1a_supply_classification.sql` | `supply_isbn_classification` | ISBN-level supply flag from title keywords (#36); built here so `has_required` (1b_) can be supply-aware (#40) |
| `1b_section_filter.sql` | `section_book_status` | One row per section: supply-aware `has_required` flag (#40); sets `is_required_inferred` on pricing |
| `2_oer_classification.sql` | `format_type_classification`, (re)builds `comprehensive_data`, four `course_materials_*` views | OER/IA lookup, master join, row flags, and canonical post-2024 Use/NoUse/Canada population (#58) |
| `2b_pricing_oer_ia.sql` | (updates `pricing_historical`) | Writes `is_oer`/`is_ia` onto pricing per `(section_id, ISBN13)` via BOOL_OR |
| `2c_pricing_wide.sql` | **`pricing_wide`** (TABLE), `pricing_wide_filtered` (view) | Pivot pricing into 18 price cols + `has_buy`/`has_rent` + fact aggs + institution enrichment |
| `2d_data_quality.sql` | `__data_quality_*` tables | Materialized DQ snapshots |

### EDA stage

| SQL file | Creates | Purpose |
|----------|---------|---------|
| `3_mailing_lists.sql` | `master_mailing`, `current_mailing`, 5 state views | Deduplicated instructor mailing lists |
| `3b_material_costs.sql` | **`section_enrollment`**, **`material_costs`** (TABLEs) | Exact section enrollment assignment; canonical Use item spine, LEFT-enriched from `pricing_wide` |
| `4_merged_records.sql` | **`section_cost`** (table), **`master_section`** (TABLE), `master_course` (view), `master_course_material` (view), `master_section_us_intro_fall2025` (view) | Material-cost section rollups, material-bearing Master Section, and BMG report view |
| `models/*.sql` | **`master_institution`**, **`master_isbn`**, **`sample10_section_ids`** (TABLEs) | Canonical term rollups and deterministic section-sample membership; `master_isbn` consumes `material_costs`; auto-discovered and materialized by `run_sql.sh` after the EDA SQL files |

### EXPORT stage

Auto-discovers `scripts/sql/exports/*.sql`; wraps each in a temp table and `COPY`s to CSV in
`output/`. (Analysis extracts like the A/B subsets and supply classification are separate
re-runnable scripts — `scripts/export_fall2025_subsets.sh`, `scripts/classify_supplies.sh` —
that write Parquet to `output/`.) `scripts/export_cmm_masters.sh` writes one release-dated CSV
per material-bearing term from the materialized Material Costs, Master Section, Master Institution, and Master ISBN tables.
`38_cmm_release_reconciliation.sql` and `39_cmm_release_key_reconciliation.sql` check the canonical
population, material-cost, section, institution, ISBN, and exact section-key paths by term after
those tables are materialized. They are split to keep the two high-cardinality states sequential.
Per-term exports are direct `period_sortable` filters of Material Costs and the three release
masters; full exports retain `period_sortable` and combine all available terms without changing
the item grain. The material-cost baseline expected for the refreshed snapshot is 12,806,060
rows: 7,476,130 have a pricing-row match and 5,329,930 do not; 5,329,933 have
NULL `price_min` because three matched pricing rows lack a valid price.

## Key tables

- **`comprehensive_data`** — the master join (catalog × IPEDS × opt-out × panel × format-type ×
  section status), ~103M rows. Owns all row-level population booleans, including the authoritative
  `is_course_material_use` / `is_course_material_no_use` partition (#58). The rerunnable
  `course_materials_post_2024`, `course_materials_use`, `course_materials_no_use`, and
  `course_materials_canada` views expose those populations without reimplementing predicates.
- **`pricing_wide`** — one row per `(section_id, isbn13)`: 18 price columns (option × condition ×
  format), `has_buy`/`has_rent`, `price_min/max`, `rental_days_min/max`, `format_count`, plus
  institution enrichment. `pricing_wide_filtered` = the `is_required_inferred` subset (view).
  Reverse-enrichment fields are retained temporarily for compatibility and raw pricing DQ; they
  do not own catalog fields in the canonical material path.
- **`section_enrollment`** — exact one row per `(period_sortable, section_id)` with authoritative
  raw enrollment/flags, section-scope dimensions, assigned enrollment, and `enrollment_source`.
  `master_section` and `material_costs` consume it so raw inputs, flags, and assignment agree.
- **`material_costs`** — materialized one row per `(period_sortable, section_id, isbn13)`
  canonical Use item. It retains items without a pricing row or valid price and uses catalog-owned title/author/publisher,
  format, FormatType, status, and flags from `comprehensive_data`; a LEFT join to `pricing_wide`
  contributes bookstore URL, all 18 price cells, `format_count`, price bounds, rental range,
  and buy bounds. Term/ISBN compatibility metadata needed by `master_isbn` is also persisted here,
  so that rollup does not return to raw catalog rows. Expected current baseline: 12,806,060 rows;
  7,476,130 pricing-row matches; 5,329,930 without a match; 5,329,933 with NULL `price_min`.
- **`section_cost`** — per-material-bearing-section required/optional cost aggregates consumed
  from `material_costs`. A section can have Use materials but no valid price, producing NULL cost
  bounds. It is not the approved item-level input.
- **`master_section`** — **materialized TABLE**, one row per distinct
  `(period_sortable, section_id)` represented in canonical `material_costs` (6,983,049 current
  rows). Material/required/optional counts, OER/IA, publishers, ISBN/FormatType, and coverage
  derive from deduplicated `material_costs`; price/cost fields join from `section_cost`; section
  dimensions, enrollment flags, and exact assigned enrollment join from `section_enrollment`.
  Compact NoUse/placeholder/Canada/supply fields are sidecar audits over source rows for retained
  material-bearing sections only—not full-population denominators. Complete valid section and
  enrollment coverage remains upstream in `section_enrollment`.
- **`master_course`** — view: one row per `(course_id, period)`, rollups of the above.
- **`master_institution`** — table: one row per `(period_sortable, unit_id)` represented by a
  material-bearing Master Section row, including an explicit NULL-unit unknown bucket when one is
  present; institution attributes, deterministic bookstore URL from all same-term `pricing_wide`
  rows, and material-section coverage/totals (#54).
- **`master_isbn`** — table: one row per `(period_sortable, isbn13)` for canonical Use
  materials consumed from `material_costs`; canonical metadata with conflict DQ, section-level
  coverage, all 18 price-cell counts, enrollment, and institution-type counts (#55).
- **`sample10_section_ids`** — table: one row per selected section, using the version-stable
  `md5-prefix64-mod10-v1` bucket-zero rule. All sampled stages join this one membership table (#53).
- **`master_section_us_intro_fall2025`** — view (BMG #38): filtered projection of `master_section`
  (Fall 2025, `required_count>=1`, intro/intermediate course levels, US only). No new columns.

## Data lineage

```mermaid
flowchart TD
    catalog["course_catalog"] --> cd["comprehensive_data<br/>~103M rows"]
    ipeds["ipeds_data"] --> cd
    optout["opt_out"] --> cd
    panel["panel"] --> cd
    ftc["format_type_classification"] --> cd
    sbs["section_book_status"] --> cd
    cd --> pop["course_materials_post_2024 / use / no_use / canada"]
    pricing["pricing_historical"] --> pw["pricing_wide (table)"]
    cd --> pw
    cd --> se["section_enrollment (table)"]
    cd --> mcst["material_costs (table)<br/>12,806,060 Use rows"]
    pw --> mcst
    cd --> mcst
    mcst --> sc["section_cost"]
    mcst --> ms["master_section (table)<br/>material-bearing sections"]
    se --> ms
    sc --> ms
    ms --> mc["master_course (view)"]
    ms --> mi["master_institution (table)"]
    pw --> mi
    mcst --> misbn
    se --> sample10["sample10_section_ids (table)<br/>full-section membership"]
    ms --> usv["master_section_us_intro_fall2025 (view)"]
    cd --> mm["master_mailing → current_mailing (+ state views)"]
```

## Key concepts

### Composite keys
- `course_id` = `unit_id::dept_code::course_number`
- `section_id` = `unit_id::dept_code::course_number::section::period_sortable` — **includes period**
  (each section-offering is its own ID). `(section_id, isbn13)` is the natural catalog grain.
- `period_sortable` = `YYYY-N` (1=Winter, 2=Spring, 3=Summer, **4=Fall**); `period_date` = canonical
  DATE for time-series axes.

### is_required_inferred (the "required code", issue #1)
Inferred is_required. TRUE when `period_date >= 2024-01-01` AND
`(has_required=TRUE AND book_status='required')` OR `(has_required=FALSE AND book_status IS NULL)`.
Applied to `comprehensive_data` and `pricing_historical`. `master_section.required_count` =
the count of canonical `material_costs` items where `is_required_inferred` is true; membership in
that table already guarantees the Use predicate. (Renamed from `filter_include`, #34.)

`has_required` is **supply-aware** (#40): `BOOL_OR(book_status='required' AND NOT is_supply)`, built in
`1a_`/`1b_`. A supply-only "required" item (e.g. safety goggles) no longer forces `has_required=TRUE`,
so a co-listed blank-status **real** textbook correctly keeps the required fallback instead of being
bucketed as optional. #41 (resolved): pseudo-SKU non-book items are overwhelmingly **legitimate**
required digital-access materials (Cengage/Pearson/MyLab access codes) — kept. Two narrow, precision-
verified gaps were folded into the supply classifier: `eyewear` supplies and explicit "no material
required" placeholder rows (`supply_category='placeholder_no_material'`). A console DQ line tracks the
remaining (legitimate) pseudo-SKU residual.

### OER/IA classification
Explicit lookup via `format_type_classification` (FormatType → `is_oer`/`is_ia` + categories).
NULL when FormatType is absent — so `has_formattype` is the classifiability flag.

### Supply classification (issue #36)
Bookstore **supplies** (lab kits, goggles, calculators, clickers, …) are identified by an
include-AND-NOT-exclude **title-keyword** classifier (`FormatType` does not encode supplies).
Keyword list: `scripts/sql/lookups/supply_keywords.tsv` (97 include + 26 exclude, single source of
truth). `1a_supply_classification.sql` builds `supply_isbn_classification` (ISBN-level, over **all
2024+** title variants) and `2_oer_classification.sql` joins `is_supply`/`supply_category` onto
`comprehensive_data`. Supplies are NoUse for every material/count/cost aggregate, while
`master_section` surfaces `is_supply` (`BOOL_OR`) + `supply_count` only for excluded source rows
that co-occur with a retained material-bearing section. Complete supply audits use
`comprehensive_data`.
Precision-over-recall (≈0.98); recall
is keyword-bounded. The `placeholder_no_material` category (#41) reuses this mechanism to exclude
explicit "no material required" placeholder rows. Supplies are <1% of Fall-2025 ISBNs — excluding them
barely moves class medians but removes the high-price tail.

### Course-material population contract (issue #58)

`comprehensive_data` owns non-null row booleans. `is_post_2024` means
`period_date >= DATE '2024-01-01'`; `has_isbn` is `ISBN13 IS NOT NULL` (the imported
numeric column maps blank source cells to NULL while retaining nonstandard numeric pseudo-SKUs);
`has_formattype` means nonblank `FormatType`; enrollment flags test non-null enrollment and
non-null `seats_taken < 9999`; `no_details` is the exact title `*No Book Details*`;
`no_materials` is the exact title `*No Books Required*` or
`supply_category='placeholder_no_material'`; and `is_canada` is `state='CAN'`.

Use is post-2024, non-Canadian, ISBN-bearing, non-supply, and neither placeholder flag. NoUse is
its exact post-2024 complement; both are false pre-2024, and Canada is a NoUse subset. No single
exclusion-reason field is stored because the reason booleans can overlap. Non-978/979 pseudo-SKUs
remain eligible unless the existing supply classifier catches them (#41).

The `master_section` row population is the distinct set of canonical Use/material keys in
`material_costs`, one row per period-specific section. `master_course` and `master_institution`
roll up that same material-bearing population. No-ISBN, no-adoption, NoUse-only, Canada-only, and
supply-only sections remain available in `comprehensive_data` and the complete
`section_enrollment` spine; they do not create release-facing Master Section rows. Sidecar audit
columns on retained rows describe excluded source records that co-occur with an included material
section and must not be interpreted as complete-population counts.

For every exported Master Section column, including its business label, owning source/aggregation,
denominator, and NULL meaning, see [`MASTER-SECTION-DICTIONARY.md`](MASTER-SECTION-DICTIONARY.md).

### Canonical material-cost spine

`material_costs` is the approved item-level input: one material row per
`(period_sortable, section_id, isbn13)` after the `comprehensive_data.is_course_material_use`
predicate. Catalog duplicates at that key collapse before enrichment; source disagreement is
retained as explicit variant/conflict signals (for example title, author, publisher, format, or
FormatType variant counts) rather than silently choosing a pricing value. A LEFT join to the
one-row-per-key `pricing_wide` table preserves all Use items, including the expected 5,329,930
without a pricing-row match. Three additional matched rows have NULL `price_min`.
`section_cost` aggregates this table; `master_section` is its one-row-per-section rollup; and
`master_isbn` rolls it up by term and ISBN. `pricing_historical` and reverse-enriched
`pricing_wide` fields remain available
for compatibility and pricing-only DQ, but are not canonical ownership for catalog attributes.

The current expected baseline is 12,806,060 material-cost rows: 7,476,130 rows match a pricing
row and 5,329,930 do not; 5,329,933 have NULL `price_min`. These are expected baseline checks for the refreshed input snapshot,
not a claim that Spring 2026 or any external source has landed locally.

### Enrollment fill (issue #32)
`section_enrollment` owns the persisted per-section enrollment, filling missing values by a
documented hierarchy; `enrollment_source` records the rung used:
`own → own_seats (<9999) → sibling_enroll → sibling_seats → class_median (control×level) →
level_median`. Medians are computed **per period** over the **reference population** (the 4 BMG
course levels × 6 real teaching sectors), so Fall-2025 in-scope rows reproduce the reviewed
analysis (cards 133/134) exactly. Raw `enrollments` is never overwritten; `enrollment_source='none'`
(NULL value) only for rows with no reachable signal.

### Pricing — rental term collapsing
`pricing_historical` grain: `(section_id, isbn13, book_option, book_condition, book_format,
rental_days)`. Buy = one price per (condition × format); rental = one price per `rental_days`
(~95 values). `pricing_wide` collapses rentals via `MAX(price)` and exposes `rental_days_min/max`.
Sentinel prices ≥ 9999 are nulled (#27).

### price_avg convention
`price_avg` / `*_cost_avg` = `(min + max) / 2`, **NOT** an arithmetic mean (legacy). Label clearly.

## Metabase

Reporting is config-as-code: 61 SQL questions (frontmatter: `-- name:`/`-- display:`/
`-- description:`) in `metabase/questions/`, dashboard JSON in `metabase/dashboards/`, IDs in
`metabase/ids.json` (keyed by filename stem), synced via `metabase/sync.py` (DB id 2). The local
image is built/launched by `metabase.sh`; it connects to `duckdb/commodore.duckdb` and holds a
read lock (DB writes require `docker stop metabase` — see `HANDOFF.md`).
