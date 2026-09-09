# Full-flow rerun

Run window: 2026-09-04 23:34:58–2026-09-05 01:27:28 PDT (1h 52m 30s)  
Branch: `cmm-spring-2026`  
Database: `duckdb/commodore.duckdb`  
Inputs: Fall 2025 catalog (`2025.12.15`), IPEDS 2024, BVA opt-out/panel files, and `BookPricing.Historical_20260224.csv`  
Command: `MEM_LIMIT=16GB NUM_THREADS=1 scripts/run_sql.sh`

The 40-file import, EDA, model, and export run completed successfully. Metabase was
stopped before the database write and restarted afterward. No Metabase publication or
external data release was performed during the rebuild.

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
| `sample_material_10pct` / distinct sections | 1,937,043 / 1,050,536 |
| `sample_section_us_intro_fall2025` | 773,613 |

The generated current exports are timestamped 2026-09-05, including
`40_master_material_by_term.csv` (18.3 GB) and the release reconciliation files.

## Validation

- 65 automated tests passed.
- Legacy-cleanup and mailing-period checks passed.
- Generated data dictionary and dashboard inventory checks passed.
- Metabase dry-run resolved 70 questions, 4 models, and 14 dashboards without publishing.
- `master_material` has no duplicate or NULL keys; 7,476,130 pricing keys matched and
  7,476,127 had a non-NULL `price_min`.

Post-run review checked the exported reconciliations: 216 release, 12 release-key,
and 13 material checks passed. Sample checks: 254 passed, zero failed, 34 not applicable
(empty/sparse populations). Live schema matches all 32 declared relations and 1,231 columns,
including types and order. The shared 12-term window intentionally expands release totals
relative to the former fixed-2024+ baseline.

### Report migration after review

Published 26 changed Metabase cards, preserving IDs, filters, collections, and dashboard
layouts. All 74 tracked SQL definitions match the repository and bind against the rebuilt
database; zero old `course_materials`/`material_costs` references remain. Live requests for
cards 78, 85, 88, and 159 passed. Renamed card 88's parameter sidecar to restore its UNITID
filter. No further ETL rebuild or external file delivery was needed.

### Documentation follow-up

The golden-path dictionary matches live DuckDB: 25 relations / 1,201 fields, excluding
seven DQ sidecars. All Notion field values were read back and matched; two unchanged
field applies made zero writes. All 26 TSV attachments matched local SHA-256 hashes;
unchanged preview/apply made zero uploads or writes. The inline database has an
all-fields view and 25 exact table filters, sorted by source column order.
All five flow/report/detail pages were published and verified. Sync conflict/recovery
tests and the complete 96-test suite pass; no additional ETL rebuild was run.
Duplicate Data Lineage/CMM ETL pages and the old container with 33 static dictionaries
were moved to recoverable Notion trash after content checks. The dictionary home now
contains only Downloads followed by the inline fields database.

### Adversarial follow-up — September 8

Independent agents compared the dictionary and all five published prose pages against
SQL and captured stakeholder requests. Corrected older-period enrollment NULL meanings,
representative-row NULL meanings, exact `format_count` derivation, and supply lookup scope
(built from recent titles, applied by ISBN to all catalog history). No additional mismatches
were found in the diagram, mailing, release/sample filters, or Jeff's raw Fall 2025 bookstore report.
Pending inputs, final master definitions, and the pricing identity issue remain explicit.

The runner now fails on missing or wrong-type outputs of selected canonical producers;
partial/export-only runs remain supported. Prose publication now detects remote edits,
skips unchanged pages, and recovers acknowledged writes after failed readback.
Changed-download publication exposed a separate API payload bug: file-block updates
must omit the nested creation-only `type`. The rejected request left the old attachment
intact; the update path was corrected and given a transport-level regression test.

Validation: 107 tests pass, including actual SQL dictionary fixtures and five real-runner
DuckDB cases (valid, missing output, wrong type, partial, export-only). Independent review,
standalone cleanup/mailing checks, and both generator freshness checks pass. Read-only
live metadata confirms all 15 canonical output names/types. All 74 live Metabase queries
and filter tags match local definitions; 14 dashboards have no dangling card mappings.
No extended rebuild, fresh overall-count scan, or external file release was performed.

Notion readback verifies both corrected prose pages, all 1,201 dictionary records
(266 updated), and all 26 TSV download hashes (nine updated). A transport interruption
after six attachment updates was reconciled by live hashes; only the remaining three
were applied. Repeated prose, dictionary, and download applies made zero remote writes.
Tracking: #90 and #91 are in Review pending PR #62 review/merge.

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
