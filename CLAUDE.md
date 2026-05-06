# CommodoreSQL — Project Conventions

## Documentation hierarchy

- `SCHEMA.md` — current data model overview (tables, pipeline stages, lineage diagram)
- `schema.dbml` — full column definitions, types, and relationships (load in dbdiagram.io)
- `CLAUDE.md` (this file) — naming standards and conventions
- `README.md` — **outdated**, do not trust until rewritten

## Naming standards

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
