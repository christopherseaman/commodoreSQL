# Full-flow rerun

Run window: 2026-09-04 23:34:58–2026-09-05 01:27:28 PDT (1h 52m 30s)  
Branch: `cmm-spring-2026`  
Database: `duckdb/commodore.duckdb`  
Inputs: Fall 2025 catalog (`2025.12.15`), IPEDS 2024, BVA opt-out/panel files, and `BookPricing.Historical_20260224.csv`  
Command: `MEM_LIMIT=16GB NUM_THREADS=1 scripts/run_sql.sh`

The 40-file import, EDA, model, and export run completed successfully. Metabase was
stopped before the database write and restarted afterward. No Metabase publication or
external data release was performed.

## Results

| relation or check | result |
| --- | ---: |
| `comprehensive_data` / `course_catalog_20251215` | 102,885,609 rows each |
| `pricing_historical` | 27,273,202 rows after dedupe; 3,021,880 removed |
| pricing residual grain | 0 |
| `section_enrollment` | 35,232,716 rows; duplicate/key/flag violations 0 |
| `course_material` | 96,663,781 rows; raw conservation difference 0 |
| canonical Use keys / `master_material` | 19,387,814 / 19,387,814; key difference 0 |
| `pricing_wide` | 11,917,462 rows; tall/wide parity difference 0 |
| mailing geographic partition | 1,374,828 rows in each side; exact match |
| `master_section` / `master_course` | 10,514,319 / 5,206,159; reconciliation violations 0 |
| `sample_material_10pct` / sample sections | 1,937,043 / 773,613 |

The generated current exports are timestamped 2026-09-05, including
`40_master_material_by_term.csv` (18.3 GB) and the release reconciliation files.

## Validation

- 65 automated tests passed.
- Legacy-cleanup and mailing-period checks passed.
- Generated data dictionary and dashboard inventory checks passed.
- Metabase dry-run resolved 70 questions, 4 models, and 14 dashboards without publishing.
- `master_material` has no duplicate or NULL keys; 7,476,130 pricing keys matched and
  7,476,127 had a non-NULL `price_min`.

## Small fixes made after the run

1. Added `${CONFIG}` to `scripts/sql/2_oer_classification.sql`. That file was the one
   regular stage not applying the requested memory/thread settings. The section
   requiredness fixture was updated to expand the new placeholder.
2. Changed the pricing period-range summary to use `period_sortable`, avoiding lexical
   `MIN(period)`/`MAX(period)` labels such as `Fall 2024 - Winter 2025` when later
   terms are present.

Both changes are configuration/reporting corrections; they do not alter the rebuilt
rows. Templating and the full test suite pass after the edits. The run's resource
measurements therefore include the old `2_oer_classification.sql` setting.

## Findings requiring separate work

- The canonical material stage took 48m 50s and spilled roughly 274 GB in `scripts/tmp`;
  the run completed with ample disk space and cleaned the temporary files. This is a
  runtime/plan optimization item, not a data failure.
- Exact pricing identity remains incomplete: 9,510,524 of 27,273,202 pricing rows did
  not match catalog rows, and 2,162,695 pricing sections were unmatched. No fallback
  join was introduced; continue the source-aware crosswalk work in #21.
- Source conflict signals remain visible in `master_material`: 1,270,518 keys have
  multiple source rows, 1,206,687 have contact conflicts, and 3,941 have catalog/
  requiredness conflicts. These are retained for audit rather than silently collapsed.
- Pricing DQ remains surfaced: 335,101 zero prices, 29,262 prices below 1, 6,159 prices
  above 1,000, and 1,336 mixed digital rental-term pairs. Seven wide rows have NULL
  bounds because their source values are round-nine sentinels (for example 9,999.99 or
  99,999); three of those appear as matched keys in `master_material` without a price.
  The existing sentinel rule and DQ reports are unchanged.
- Recent catalog DQ still includes unknown composite-key segments, missing/non-IPEDS
  unit IDs, null or malformed emails, negative enrollments, and enrollment overages.
  These are measured in `__data_quality_metrics`; no broad fallback or source rewrite
  was made in this rerun.
- `output/` contains both the current 2026-09-05 exports and older manually generated
  parquet/gzip/reconciliation artifacts. Do not release the directory wholesale until
  the intended artifact set is selected.
- Pending source drops and definitions (Spring 2026, bookstore-brand lookup, final
  Master Course/Institution contract, and related external decisions) remain blocked as
  recorded in `HANDOFF.md`.
