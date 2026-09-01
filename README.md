# CommodoreSQL

CommodoreSQL is a DuckDB pipeline for course-material analysis and mailing-list production.
It combines BMG and BVA inputs with IPEDS metadata and a Metabase reporting layer.

## Documentation

- [`HANDOFF.md`](HANDOFF.md) — current branch, release state, blockers, and pickup steps
- [`SCHEMA.md`](SCHEMA.md) — execution order, relations, and data lineage
- [`CMM-ETL.md`](CMM-ETL.md) — release-facing processing contract
- [`DATA-DICTIONARY.md`](DATA-DICTIONARY.md) — authoritative relation and column dictionary
- [`schema.dbml`](schema.dbml) — canonical machine-readable schema
- [`DASHBOARDS-REPORTS.md`](DASHBOARDS-REPORTS.md) — Metabase inventory
- [`COURSE-MATERIAL-POPULATIONS.md`](COURSE-MATERIAL-POPULATIONS.md) — population and denominator guide
- [`MAILING-FLOW.md`](MAILING-FLOW.md) — mailing Master, Working, and export flow
- [`PRICING-CATALOG-MATCHING.md`](PRICING-CATALOG-MATCHING.md) — pricing/catalog identity limitation

## Inputs and configuration

Source files live under `data/<date>/`; configure paths and runtime settings in `scripts/dot.env`.

| Owner | Input | Imported relation |
|---|---|---|
| BMG | `DiscoveryExtract.*.csv` | `course_catalog_<date>` |
| BMG | `BookPricing.Historical_*.csv` | `pricing_historical` |
| BVA | `OptOut_*.csv` | `opt_out` |
| BVA | `panel_*.csv` | `panel` / `panel_email` |
| IPEDS | `IPEDS_2024.csv` | `ipeds_data` |
| Internal | `format_type_lookup.tsv` | `format_type_classification` |

## Run

```bash
scripts/run_sql.sh
```

The runner loads `scripts/dot.env`, applies `envsubst` to SQL, and runs IMPORT, EDA/model,
and EXPORT against `MAIN_DB`. Set `NO_IMPORT=1`, `NO_EDA=1`, or `NO_EXPORT=1` to
skip a stage. The pipeline drops and recreates managed relations, so it is re-runnable.

```bash
NO_IMPORT=1 NO_EXPORT=1 scripts/run_sql.sh  # run EDA + models from existing import state
```

## Relation flow

```text
source CSVs
  -> comprehensive_data
  -> course_materials + section_enrollment
  -> course_materials_use -> material_costs
  -> pricing_historical -> pricing_wide -> material_costs
  -> section_cost
  -> master_section / master_institution / master_isbn

course-material source -> master_mailing -> current_mailing -> geographic exports
```

`course_materials` is the canonical catalog item spine; `material_costs` left-enriches its
Use items with exact section×ISBN pricing. `section_enrollment` owns the complete section
population, while the three master relations are material-bearing release rollups.

## Release exports

```bash
scripts/export_cmm_masters.sh             # every material-bearing term
scripts/export_cmm_masters.sh 2025-4      # one term
scripts/export_course_materials.sh 20260901
scripts/export_course_materials.sh 20260901 2025-4
```

CMM files go under `output/cmm/`; Course Materials files go under `output/course_materials/`.
Both are configurable, and the Course Materials exporter refuses to overwrite files.

## Metabase

Questions, models, dashboards, and IDs live under `metabase/`. Preview with
`python3 metabase/sync.py --dry-run`; `./metabase.sh` recreates the read-only service.
