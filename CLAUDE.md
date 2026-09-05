# CommodoreSQL — Project Conventions

## Documentation style

- Use exact table/view names in diagrams; put logic below them.
- State shared rules once. Cut repeated introductions, aliases, and qualifications.
- Preserve fields, filters, grains, and export/report inventories when shortening.
- Edit generated wording at its source; regenerate and verify Notion tables.

## Documentation hierarchy

- `CMM-DATA-FLOW.md` — source-to-report flow, processing logic, filters, and export inventory
- `DATA-DICTIONARY.md` — schema home, generated relation index, and downloadable TSV
- `docs/data-dictionary.tsv` — generated golden-path schema, one row per relation/column
- `docs/data-dictionary/<relation>.tsv` — downloadable slices of the global TSV
- `docs/data-dictionary/<relation>.md` — generated repo-only reference pages, including DQ
- `schema.dbml` — canonical machine-readable column definitions, types, and relationships (load in dbdiagram.io)
- `SCHEMA.md`, `CMM-ETL.md` — repo-only pointers retained for older references
- `MASTER-SECTION-DICTIONARY.md` — repo-only Master Section business/NULL/denominator appendix
- `DASHBOARDS-REPORTS.md` — dashboard, report, and Metabase question inventory
- `CLAUDE.md` (this file) — naming standards and conventions
- `HANDOFF.md` — current work status, how to run things, gotchas (read first when picking up)
- `README.md` — project overview, execution order, runner configuration, and export commands

Notion prose sync uses `scripts/notion_sync_docs.txt`: flow, reports, and three issue-detail
pages beneath CMM Data Flow. It strips ordinary repository-relative links and preserves
native child pages. No recursive repository sweep.

Data Dictionary uses dedicated field and download publishers, configured by
`scripts/notion_dictionary.json`. One inline database holds the implemented flow's columns;
table-filtered views and a collapsed Downloads section expose global/per-table TSVs.
DQ and off-flow relations are excluded. Generated TSVs flow one-way into Notion;
publishers detect remote edits and retain stable row/file-block IDs.
Local sync state lives in ignored `.notion/`; preserve it between runs.

Use `NOTION_KEYRING=0`; preview before `--apply` (commands in README.md).
Repo-only guidance, historical notes, and `comms/` captures are not synced.

## Naming standards

- Derived relations use singular nouns: `course_material`, `master_material`,
  `master_section`, `recent_period`.
- Samples use `sample_<grain>_<selection>`: `sample_material_10pct`,
  `sample_section_us_intro_fall2025`, and pending `sample_material_25id` /
  `sample_section_25id` from the imported `sample_unit_25id` list.
- Source-owned field names and plural count/list measures retain their meanings.

### Stakeholder source ownership

- BMG owns course-materials and raw pricing/cost observations.
- BVA owns opt-out and mailing-history inputs.
- IPEDS owns institution metadata.
- Existing executable source-table names are compatibility names; do not claim they use source
  prefixes. Derived/joined outputs omit stakeholder acronyms.

### Fact aggregation columns

When aggregating a numeric or count fact, name the column `<dimension>_<aggfunc>`:

| Dimension | aggfunc | Column name |
|-----------|---------|-------------|
| price | min | `price_min` |
| price | max | `price_max` |
| price | avg | `price_avg` |
| format | count | `format_count` |
| rental_days | min | `rental_days_min` |
| rental_days | max | `rental_days_max` |

**Why:** keeps related aggregations sorted/grouped alphabetically and makes their family obvious.

**Don't use:** `min_price`, `max_price`, `average_price`, `num_formats_available`, etc.

### Boolean DQ pairs

When deriving a boolean from grouped data via `BOOL_OR` and `BOOL_AND`:

- The `BOOL_OR` value is the **definitive** column — name it without a suffix (`is_oer`, `is_ia`).
- Compare against `BOOL_AND` only as a data-quality check, **logged to console**, not stored.
- TODO: better DQ logging — currently console-only.

### Requiredness booleans

- Name derived requiredness booleans `is_required_<method>`.
- Use `is_required_direct` for explicit source evidence and
  `is_required_inferred` for fallback classification.
- State the grain: at section grain, direct means any qualifying material; at item grain,
  it applies only to that item.
- Preserve source-owned fields such as `book_status` and `pricing_historical.required`.

## Pipeline conventions

- All SQL files in `scripts/sql/` are envsubst-templated; reference env vars as `${VAR}`.
- IMPORT stage prefixes: `0_`, `1_`, `1b_`, `2_`, `2b_`, `2c_`. Sub-prefixes (`b`, `c`) sequence dependent steps within the same logical stage.
- DROP before CREATE; pipeline must be re-runnable.
- Console output is the current "logging" channel. Aggregate counts and DQ checks should produce single-line summary rows.

## Gotchas

These are non-obvious behaviors worth knowing before joining or aggregating.

### `section_id` is period-specific

`section_id` = `unit_id::dept_code::course_number::section::period_sortable` — period is **part of** the ID. Each section-offering has its own ID; a section taught in Fall 2024 and Spring 2025 has two distinct `section_id`s.

**Implications:**
- `(section_id, isbn13)` is the natural unique grain on the catalog side (modulo a small number of within-period source-data dupes).
- `course_id` (which omits section + period) is the right key when aggregating across offerings.

### `pricing_historical` multiplicity at `(section_id, isbn13)`

`pricing_historical` is at `(section_id, isbn13, book_option, book_condition, book_format, rental_days)` grain — i.e., ~3.46 rows per `(section_id, isbn13)` from purchase format combinations. This collapses cleanly via the wide pivot's `MAX(price)` aggregations. No special handling needed when consuming `pricing_wide` — it's already 1:1 on `(section_id, isbn13)`.

### NULL `ISBN13` rows in `comprehensive_data`

~54% of catalog rows have NULL `ISBN13` — sections without book adoptions, or course rosters where the book wasn't entered. These are typically meaningless for book-level analysis. Exclude them when joining on ISBN.

### `pricing_historical` rental term variation

Pricing is at `(section_id, isbn13, book_option, book_condition, book_format, rental_days)` grain.

- **buy** rows have exactly one price per `(condition, format)` combo.
- **rental** is the **only** option with multiple price points per `(condition, format)` — one price per rental term (`rental_days` ∈ {30, 60, 90, 120, 180, 365, 1825, …}; ~95 distinct values).

`pricing_wide` collapses rental terms via `MAX(price)` per pivot cell, and surfaces the term range as `rental_days_min` / `rental_days_max`. For per-term rental pricing, query `pricing_historical` directly.

### `price_avg` is NOT the arithmetic mean

`price_avg` = `(price_min + price_max) / 2.0` — **legacy** definition kept for backward compatibility. Wherever surfaced in Metabase or exports, label clearly so consumers don't assume `AVG()`.

## When in doubt

- Prefer **DuckDB-native** functions (`BOOL_OR`, `LIST`, `FILTER (WHERE …)`, `IS NOT DISTINCT FROM`) over portable SQL where they're clearer.
- Source data has noise (duplicate rows, NULL options, embedded text in emails). Document tolerated noise; don't dedupe silently.
