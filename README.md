# CommodoreSQL

DuckDB pipeline for course materials, pricing, mailing, and Metabase reports.

## Documentation

- [Data flow](CMM-DATA-FLOW.md)
- [ETL rules](CMM-ETL.md) · [Schema](SCHEMA.md) · [DBML](schema.dbml)
- [Data dictionary](DATA-DICTIONARY.md) · [Reports](DASHBOARDS-REPORTS.md)
- [Material populations](COURSE-MATERIAL-POPULATIONS.md) · [Mailing](MAILING-FLOW.md) · [Pricing mismatch](PRICING-CATALOG-MATCHING.md)
- [Status and next steps](HANDOFF.md)

## Inputs and configuration

Files: `data/<date>/`. Configuration: `scripts/dot.env`.

| Owner | Input | Imported relation |
|---|---|---|
| BMG | `DiscoveryExtract.*.csv` | `course_catalog_<date>` |
| BMG | `BookPricing.Historical_*.csv` | `pricing_historical` |
| BVA | `OptOut_*.csv` | `opt_out` |
| BVA | `panel_*.csv` | `panel` |
| IPEDS | `IPEDS_2024.csv` | `ipeds_data` |
| Internal | `format_type_lookup.tsv` | `format_type_classification` |

## Run

```bash
scripts/run_sql.sh
```

Loads `scripts/dot.env`, templates SQL, and rebuilds managed relations in `MAIN_DB`.
Skip stages with `NO_IMPORT=1`, `NO_EDA=1`, or `NO_EXPORT=1`.

```bash
NO_IMPORT=1 NO_EXPORT=1 scripts/run_sql.sh  # run EDA + models from existing import state
```

## Release exports

```bash
scripts/export_cmm_masters.sh             # every material-bearing term
scripts/export_cmm_masters.sh 2025-4      # one term
scripts/export_course_material.sh 20260901
scripts/export_course_material.sh 20260901 2025-4
```

Default destinations: `output/cmm/` and `output/course_material/`.
Course Materials exports refuse overwrites.

## Metabase

Config: `metabase/`. Preview: `python3 metabase/sync.py --dry-run`.
`./metabase.sh` recreates the read-only service.
