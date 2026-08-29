# CommodoreSQL

A DuckDB pipeline that integrates course-catalog data (~103M rows) with institutional
characteristics (IPEDS), bookstore pricing, and opt-out/panel lists — to support targeted
mailing lists and analysis of course-materials cost and OER/Inclusive-Access adoption.

> **Where to look:** current work status, how to run things, and gotchas in
> [`HANDOFF.md`](HANDOFF.md) · exact execution/file lineage in
> [`SCHEMA.md`](SCHEMA.md#data-lineage) · release-facing process, filters, and derived-field
> semantics in [`CMM-ETL.md`](CMM-ETL.md) · full column
> definitions in [`schema.dbml`](schema.dbml) (load in dbdiagram.io) · Master Section release
> columns in [`MASTER-SECTION-DICTIONARY.md`](MASTER-SECTION-DICTIONARY.md) · naming standards in
> [`CLAUDE.md`](CLAUDE.md) · historical design decisions in
> [`260529-DECISIONS.md`](260529-DECISIONS.md).

## Data sources

CSVs live under `data/<date>/`; paths are configured in `scripts/dot.env`.

| File | Target table | Rows |
|------|--------------|------|
| `DiscoveryExtract.*.csv` | `course_catalog_<date>` | ~103M |
| `IPEDS_2024.csv` | `ipeds_data` | ~7K |
| `OptOut_*.csv` | `opt_out` | variable |
| `panel_*.csv` | `panel` | variable |
| `format_type_lookup.tsv` | `format_type_classification` | 69 |
| `BookPricing.Historical_*.csv` | `pricing_historical` | snapshot-dependent (~27.3M current rows) |

## Running the pipeline

```bash
scripts/run_sql.sh
```

The runner loads `scripts/dot.env`, templates each `scripts/sql/*.sql` file (env vars via
`envsubst`, e.g. `${CONFIG}`), and executes it against the DuckDB database at `MAIN_DB`
(`duckdb/commodore.duckdb`). It runs three stages, each skippable by setting a flag:

| Stage | Flag to skip | What it does |
|-------|--------------|--------------|
| IMPORT | `NO_IMPORT` | Load CSVs; derive composite keys; retain raw panel plus one-row-per-email `panel_email`; build enriched source-row `comprehensive_data`; classify catalog OER/IA; canonicalize `course_materials` and `section_enrollment`; build source-owned pricing history/wide tables and non-mutating DQ comparisons |
| EDA | `NO_EDA` | Build mailing lists from `comprehensive_data`, canonical `material_costs` as the only pricing enrichment of `course_materials_use`, section/course records, and materialize `scripts/sql/models/*.sql` rollups |
| EXPORT | `NO_EXPORT` | Auto-discover `scripts/sql/exports/*.sql`, wrap each in a temp table, `COPY` to CSV in `output/` |

```bash
NO_IMPORT=1 NO_EXPORT=1 scripts/run_sql.sh   # rebuild just the EDA records
```

Update `CSV_DATE` in `scripts/dot.env` for a new data drop. The pipeline drops-before-creates
and is re-runnable.

## Key outputs

- **`comprehensive_data`** — exactly one enriched, normalized BMG source row (catalog × IPEDS ×
  opt-out × one-row-per-email panel lookup × format-type × section status), with row-level 2024+
  Use/NoUse/Canada, coverage, enrollment, placeholder, supply, required, and OER/IA flags. It
  remains the source for mailing, faculty, and raw DQ; the rebuilt source and enriched tables
  each contain 102,885,609 rows.
- **`course_materials`** — first canonical processed table at one
  `(period_sortable, section_id, isbn13)`, plus one NULL-ISBN audit row per section when present;
  source counts, representative fields, variants/conflicts, and population flags are retained.
  It contains 96,663,781 rows; the four `course_materials_*` views are direct canonical
  projections.
- **`section_enrollment`** — exact one-row-per-section enrollment assignment and provenance,
  built during canonical Course Materials stage and retaining the complete valid 2024+ spine.
- **`material_costs`** (materialized TABLE) — one row per
  `(period_sortable, section_id, isbn13)` canonical Use item. It is the approved item input:
  catalog-owned fields come from `course_materials`, while a LEFT join to `pricing_wide`
  adds bookstore URL, all 18 price cells, format/price bounds, rental range, and buy bounds.
  Every Use item remains present, including items without a pricing-row match or valid price.
- **`section_cost`** — section-level required/optional cost rollups consumed from
  `material_costs`; it is not the item-level input.
- **`master_section`** (materialized TABLE) / **`master_course`** (view) — one row per
  material-bearing section-offering / course-offering (2024+). Master Section is the section-level
  rollup of canonical `material_costs` items, with section dimensions and assigned enrollment from
  `section_enrollment`; all price/cost fields roll through `section_cost`. The independent
  `section_enrollment` table retains the complete valid section population.
- **`pricing_historical`** / **`pricing_wide`** — indexed, deduplicated source pricing and its
  one-row-per-`(section_id, isbn13)` provenance/price pivot. Neither table receives catalog
  required-inference, OER/IA, or IPEDS fields, and there is no required-only pricing view.
  `2d_data_quality.sql` compares pricing to catalog without mutating either table. Exact-match
  evidence and future proposals are centralized in the
  [issue #21 limitation](CMM-ETL.md#current-limitation--pricing-to-catalog-section-matching-issue-21).
- **`master_section`** / **`master_institution`** / **`master_isbn`** (materialized TABLEs) —
  the three per-term CMM release masters. `material_costs` is exported alongside them;
  `master_isbn` consumes it. Institution and strict term×ISBN rollups live in
  `scripts/sql/models/`; combined exports live in `output/`.
- **`sample10_section_ids`** — canonical deterministic section-level sample membership;
  sampled exports and reconciliation reuse this table rather than drawing independently.
- **Mailing lists** — `master_mailing`, `current_mailing`, and state-specific views.

To create separate release-dated files for every material-bearing term, or only Fall 2025:

```bash
scripts/export_cmm_masters.sh
scripts/export_cmm_masters.sh 2025-4
```

To export the five canonical Course Materials relations (optionally for one `YYYY-N` term):

```bash
scripts/export_course_materials.sh              # all terms, date from today
scripts/export_course_materials.sh 20250828      # all terms, explicit release date
scripts/export_course_materials.sh 20250828 2025-4
```

Files are written under `output/course_materials` (configurable) as dated
`course_materials`, `course_materials_post_2024`, `course_materials_use_post_2024`,
`course_materials_nouse_post_2024`, and `course_materials_can_post_2024` CSVs.

Each selected term emits `master_section`, `master_institution`, `master_isbn`, and
`material_costs` CSVs under `output/cmm/`. All four releases follow the canonical Use/material
population: Master Section and Institution contain sections represented by `material_costs`,
including sections whose Use items have no pricing match or valid price. Complete catalog and
enrollment populations remain available upstream in `comprehensive_data` and `section_enrollment`.
The material-cost baseline is expected to contain **12,806,060** Use rows. Per-term files are
direct filters of the materialized masters; full Material Costs export is
`scripts/sql/exports/40_material_costs_by_term.sql`.
Full exports retain `period_sortable` and do not multiply rows across terms. Source/input readiness remains tracked in #51; Spring 2026 and
`cmm_discipline` are external pending inputs, not landed local tables.
Exact cross-model and key-set checks are exported by `38_cmm_release_reconciliation.sql` and
`39_cmm_release_key_reconciliation.sql`; `41_material_costs_reconciliation.sql` reconciles raw
source rows through canonical `course_materials` to `material_costs`; every row must match.

## Metabase

Dashboards and questions are config-as-code: SQL questions (with frontmatter) in
`metabase/questions/`, dashboard layouts in `metabase/dashboards/`, IDs in `metabase/ids.json`,
synced via `metabase/sync.py`. The local image is built/launched by `metabase.sh` (custom
glibc-based image so the DuckDB driver works). It connects read-only to `duckdb/commodore.duckdb`.
