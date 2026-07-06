# CommodoreSQL

A DuckDB pipeline that integrates course-catalog data (~103M rows) with institutional
characteristics (IPEDS), bookstore pricing, and opt-out/panel lists — to support targeted
mailing lists and analysis of course-materials cost and OER/Inclusive-Access adoption.

> **Where to look:** current work status, how to run things, and gotchas in
> [`HANDOFF.md`](HANDOFF.md) · data model overview in [`SCHEMA.md`](SCHEMA.md) · full column
> definitions in [`schema.dbml`](schema.dbml) (load in dbdiagram.io) · naming standards in
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
| EDA | `NO_EDA` | Build mailing lists and the `master_section` / `master_course` / `section_cost` records |
| EXPORT | `NO_EXPORT` | Auto-discover `scripts/sql/exports/*.sql`, wrap each in a temp table, `COPY` to CSV in `output/` |

```bash
NO_IMPORT=1 NO_EXPORT=1 scripts/run_sql.sh   # rebuild just the EDA records
```

Update `CSV_DATE` in `scripts/dot.env` for a new data drop. The pipeline drops-before-creates
and is re-runnable.

## Key outputs

- **`comprehensive_data`** — the master join (catalog × IPEDS × opt-out × panel × format-type ×
  section status), with `filter_include` (2024+ required-material scope) and OER/IA flags.
- **`master_section`** (materialized TABLE) / **`master_course`** (view) — one row per
  section-offering / course-offering (2024+): institution enrichment, material counts, OER/IA
  indicators, coverage + enrollment fill-potential flags (`has_enrollment*`), and
  required/non-required cost columns. Cost is computed in **`section_cost`**.
- **`pricing_wide`** (all priced materials) / **`pricing_wide_filtered`** (required subset) —
  18 price columns pivoted per `(section_id, isbn13)`.
- **Mailing lists** — `master_mailing`, `current_mailing`, and state-specific views.

## Metabase

Dashboards and questions are config-as-code: SQL questions (with frontmatter) in
`metabase/questions/`, dashboard layouts in `metabase/dashboards/`, IDs in `metabase/ids.json`,
synced via `metabase/sync.py`. The local image is built/launched by `metabase.sh` (custom
glibc-based image so the DuckDB driver works). It connects read-only to `duckdb/commodore.duckdb`.
