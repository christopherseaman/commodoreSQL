# CommodoreSQL

DuckDB pipeline for course materials, pricing, mailing, and Metabase reports.

## Documentation

- [Data flow](CMM-DATA-FLOW.md)
- [Data dictionary](DATA-DICTIONARY.md) · [Schema TSV](docs/data-dictionary.tsv) · [DBML](schema.dbml)
- [Reports](DASHBOARDS-REPORTS.md)
- [Material populations](COURSE-MATERIAL-POPULATIONS.md) · [Mailing](MAILING-FLOW.md) · [Pricing mismatch](PRICING-CATALOG-MATCHING.md)
- [Master Section business/NULL appendix](MASTER-SECTION-DICTIONARY.md)
- [Status and next steps](HANDOFF.md)

## Inputs and configuration

Files: `data/<date>/`. Configuration: `scripts/dot.env`.

| Owner | Input | Imported relation |
|---|---|---|
| BMG | `DiscoveryExtract.*.csv` | `course_catalog_<date>` |
| BMG | `BookPricing.Historical_*.csv` | `pricing_historical` |
| BVA | `OptOut_*.csv` | `opt_out` |
| BVA | `panel_*.csv` | `panel_email` |
| IPEDS | `IPEDS_2024.csv` | `ipeds_data` |
| Internal | `format_type_lookup.tsv` | `format_type_classification` |

## Run

```bash
scripts/run_sql.sh
```

Loads `scripts/dot.env`, templates SQL, and rebuilds managed relations in `MAIN_DB`.
Skip stages with `NO_IMPORT=1`, `NO_EDA=1`, or `NO_EXPORT=1`.

`CUSTOM_SQL_FILES` replaces the file list. SQL uses `envsubst`; normal runs DROP/recreate
managed relations. Stop Metabase before database writes and restart it afterward.

| Stage | Execution order |
|---|---|
| Import | `0_cleanup`, `0_setup`, `0b_state_region`, `0c_recent_period`, `1_bookprices_import`, `1a_supply_classification`, `1b_section_enrollment`, `2_oer_classification`, `2b_course_material`, `2c_pricing_wide`, `2d_data_quality` |
| EDA | `3_mailing_lists`, `3b_master_material`, `4_merged_records` |
| Models | `master_institution`, `master_isbn`, `sample_material_10pct` (`scripts/sql/models/*.sql`, lexically) |
| Export | 23 top-level `scripts/sql/exports/*.sql`, lexically, to `output/<basename>.csv` |

`0_setup.sql` also writes `output/email_issues.tsv`. After import, mailing export requires
`3_mailing_lists.sql`; wrapper-only runs can use previously refreshed mailing relations.
`0_cleanup.sql` removes exact retired/report/geographic targets and fails if any remain.
Exports `37`–`39` and `41` contain reconciliation results, which require checking after a run.

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

Other explicit runners: `export_fall2025_subsets.sh` writes Set A/B Parquets;
`classify_supplies.sh` writes the separate `fall2025_supply_isbns.parquet` audit;
`export_all.sh` runs the 23 CSV wrappers; `export_all_parquet.sh` runs the same wrappers
as Parquet, removing numeric filename prefixes.

## Metabase

Config: `metabase/`. Preview: `python3 metabase/sync.py --dry-run`.
`./metabase.sh` recreates the read-only service.

## Notion documentation

Edit schema/field metadata at its source; regenerate before publishing.
The dictionary covers the implemented flow, excluding DQ and off-flow relations.

```bash
python3 scripts/generate_data_dictionary.py
python3 scripts/generate_data_dictionary.py --check
NOTION_KEYRING=0 python3 scripts/sync_notion_dictionary.py
NOTION_KEYRING=0 python3 scripts/sync_notion_dictionary_downloads.py
NOTION_KEYRING=0 python3 scripts/sync_notion_docs.py --manifest scripts/notion_sync_docs.txt
```

Each sync command previews by default; add `--apply` to publish after a clean preview.
Run publishers sequentially. Targets: `scripts/notion_dictionary.json`.
Preserve ignored `.notion/` state for remote-edit detection. Conflicts stop publication;
reconcile edits locally before retrying. New columns sync automatically; a changed table
set requires an explicit attachment migration and adding/removing its filtered Notion views.
Record view IDs in the target configuration.
