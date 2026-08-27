# CommodoreSQL

A DuckDB pipeline that integrates course-catalog data (~103M rows) with institutional
characteristics (IPEDS), bookstore pricing, and opt-out/panel lists — to support targeted
mailing lists and analysis of course-materials cost and OER/Inclusive-Access adoption.

> **Where to look:** current work status, how to run things, and gotchas in
> [`HANDOFF.md`](HANDOFF.md) · data model overview in [`SCHEMA.md`](SCHEMA.md) · full column
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
| `BookPricing.Historical_*.csv` | `pricing_historical` | ~11K |

## Running the pipeline

```bash
scripts/run_sql.sh
```

The runner loads `scripts/dot.env`, templates each `scripts/sql/*.sql` file (env vars via
`envsubst`, e.g. `${CONFIG}`), and executes it against the DuckDB database at `MAIN_DB`
(`duckdb/commodore.duckdb`). It runs three stages, each skippable by setting a flag:

| Stage | Flag to skip | What it does |
|-------|--------------|--------------|
| IMPORT | `NO_IMPORT` | Load CSVs; derive composite keys; build `comprehensive_data`; classify OER/IA; pivot pricing |
| EDA | `NO_EDA` | Build mailing lists, exact `section_enrollment`, canonical `material_costs`, section/course records, and materialize `scripts/sql/models/*.sql` rollups |
| EXPORT | `NO_EXPORT` | Auto-discover `scripts/sql/exports/*.sql`, wrap each in a temp table, `COPY` to CSV in `output/` |

```bash
NO_IMPORT=1 NO_EXPORT=1 scripts/run_sql.sh   # rebuild just the EDA records
```

Update `CSV_DATE` in `scripts/dot.env` for a new data drop. The pipeline drops-before-creates
and is re-runnable.

## Key outputs

- **`comprehensive_data`** — the master join (catalog × IPEDS × opt-out × panel × format-type ×
  section status), with row-level 2024+ Use/NoUse/Canada, coverage, enrollment, placeholder,
  supply, required, and OER/IA flags. It owns the canonical Use/NoUse partition; the
  `course_materials_*` views are direct projections of those flags.
- **`section_enrollment`** — exact one-row-per-section enrollment assignment and provenance.
- **`material_costs`** (materialized TABLE) — one row per
  `(period_sortable, section_id, isbn13)` canonical Use item. It is the approved item input:
  catalog-owned fields come from `comprehensive_data`, while a LEFT join to `pricing_wide`
  adds bookstore URL, all 18 price cells, format/price bounds, rental range, and buy bounds.
  Every Use item remains present, including items without a pricing-row match or valid price.
- **`section_cost`** — section-level required/optional cost rollups consumed from
  `material_costs`; it is not the item-level input.
- **`master_section`** (materialized TABLE) / **`master_course`** (view) — one row per
  section-offering / course-offering (2024+). The deliberately broader complete section and
  enrollment spine is retained; non-cost material fields use canonical Use rows from
  `comprehensive_data`, while all price/cost fields roll from `material_costs` via `section_cost`.
- **`pricing_wide`** (all priced materials) / **`pricing_wide_filtered`** (required subset) —
  reverse-enrichment compatibility views/tables with 18 price columns pivoted per
  `(section_id, isbn13)`. They remain useful for raw pricing DQ, not canonical item ownership.
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

Each selected term emits `master_section`, `master_institution`, `master_isbn`, and
`material_costs` CSVs under `output/cmm/`. Master Section and Institution preserve all valid
2024+ section/enrollment denominators while Master ISBN and all material/pricing metrics use the
#58 Use population.
The material-cost baseline is expected to contain **12,806,060** Use rows: **7,476,130**
have a pricing-row match and **5,329,930** do not. **5,329,933** rows have no valid
`price_min`, including three matched pricing rows. Per-term files are direct filters of the
materialized masters; full Material Costs export is `scripts/sql/exports/40_material_costs_by_term.sql`.
Full exports retain `period_sortable` and do not multiply rows across terms. Source/input readiness remains tracked in #51; Spring 2026 and
`cmm_discipline` are external pending inputs, not landed local tables.
Exact cross-model and key-set checks are exported by `38_cmm_release_reconciliation.sql` and
`39_cmm_release_key_reconciliation.sql`; every row must match.

## Metabase

Dashboards and questions are config-as-code: SQL questions (with frontmatter) in
`metabase/questions/`, dashboard layouts in `metabase/dashboards/`, IDs in `metabase/ids.json`,
synced via `metabase/sync.py`. The local image is built/launched by `metabase.sh` (custom
glibc-based image so the DuckDB driver works). It connects read-only to `duckdb/commodore.duckdb`.
