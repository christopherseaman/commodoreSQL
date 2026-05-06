# TODO

## Data quality logging

Currently the import pipeline logs DQ checks to console only (e.g., OER/IA `BOOL_OR` vs `BOOL_AND` consistency in `2b_pricing_oer_ia.sql`, tall-vs-wide cell-count parity in `2c_pricing_wide.sql`). Console output disappears when the run ends.

Decide on a persistent DQ logging surface — options:
- TSV artifact per check, written to `output/dq/`
- Single dedicated `dq_log` table with `(timestamp, sql_file, metric, value, status)`
- Stderr → log file via `tee`

## NULL `ISBN13` in `comprehensive_data`

~54% of `comprehensive_data` rows (~55.7M / 102.9M) have `ISBN13 IS NULL`. Investigate:

- Are these course rosters where no book was entered? (Likely yes for some.)
- Are some periods/courses systematically missing ISBNs vs. having them populated?
- Should NULL-ISBN rows be excluded earlier in the pipeline, or left for downstream filtering?
- Does this affect any current Metabase question or export?

If these are genuinely "no book adopted" rows, they should still be retained for enrollment/section counts but excluded from book-level joins — codify the rule.

## Pricing↔catalog `section_id` normalization (filter_include=FALSE only)

DQ investigation (2026-05-05) found ~33% of distinct pricing `section_id`s don't match `comprehensive_data`. **Filter_include=TRUE pricing sections are 100% matched** — the unmatched sections live entirely in `filter_include=FALSE` rows (pre-2024 / non-required materials), so this does not affect filtered analysis today.

If pre-2024 pricing analysis becomes a use case, normalize `section_id` derivation between pricing and catalog. Likely causes (need side-by-side comparison):
- Course code formatting differences (`ENG 101` vs `ENG101`, leading zeros, suffix letters)
- Section number padding (`01` vs `1`)
- Whitespace/casing in `Department Code` or `Course Code` columns

The DQ check in `2b_pricing_oer_ia.sql` produces a top-10 `(unit_id, period_sortable)` list of high-unmatched institutions among `filter_include=FALSE` sections — start there for spot-checking.

## README rewrite

`README.md` is severely out of date — it references `csv/Bayview.YYYYMMDD.csv`, `scripts/run_all.sh`, `scripts/0_setup.sh`, etc., none of which exist. Rewrite to reflect the actual `run_sql.sh` pipeline and `data/` layout. Keep README high-level; gotchas live in `CLAUDE.md`, schema in `SCHEMA.md` / `schema.dbml`.
