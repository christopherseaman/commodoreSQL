# HANDOFF — CommodoreSQL / BMG cost-data analysis

Pickup context as of **2026-07-06**. Read this first, then `SCHEMA.md` (data model) and
`CLAUDE.md` (conventions). Work tracking is **GitHub Issues + Projects board**, not this file.

## What this repo is

A DuckDB pipeline (`duckdb/commodore.duckdb`, ~71 GB) that joins course-catalog data
(~103M rows) with IPEDS, bookstore pricing, and opt-out/panel lists, plus a
**Metabase config-as-code** reporting layer (`metabase/`) and a GitHub Projects board.

- Branch: **`data-model-derived-columns`** (push to it, **no PR** — team convention).
- Board lifecycle: Todo → On Deck → In Progress → **Review** → Done. **Review = human
  review**; Claude sets Review only after self-validating, the human owns Review → Done.

## Current focus — BMG grant cost analysis (Bay View Analytics / Jeff Seaman)

Fixed initial-analysis scope: **Fall 2025** (`period_sortable='2025-4'`). Everything is built
**re-runnable** so it regenerates after the planned supply-ISBN exclusion.

### Done and in Review

| # | Deliverable | Where |
|---|---|---|
| #35 | A/B subsets (Set A = ≥1 required, Set B = none), 5 tallies, enrollment assignment | Metabase cards **126/127**, **128–132**, **133/134**; questions `35`,`37`–`45`; `scripts/export_fall2025_subsets.sh` → Parquet |
| #37 | Master ISBN dataset (one row per ISBN13×Title×Author×Format×FormatType) | card **157**, question `46_master_isbn_fall2025.sql` |
| #38 | `master_section` US intro/intermediate required VIEW | DB view **`master_section_us_intro_fall2025`** (in `4_merged_records.sql`), GUI-queryable in Metabase |
| #36 | Supply-vs-course-material ISBN classifier + **model integration** | `scripts/sql/lookups/supply_keywords.tsv` (84 incl + 26 excl), `scripts/classify_supplies.sh`; `is_supply`/`supply_category` on `comprehensive_data`, `is_supply`/`supply_count` on `master_section` |
| #32 | **Persisted** `enrollment_assigned`/`enrollment_source` on `master_section` | `4_merged_records.sql` (per-period medians over the scope reference population); cards 133/134 now project the columns |
| #39 | Metabase **Models** (`master_section` 158, US-intro-scope 159) + **3 dashboards** (Overview 18, Cost-hypothesis 16, Enrollment-DQ 17) | `metabase/models/*.sql`, `metabase/dashboards/bmg_*.json`, `sync.py` model support |

Scope filter (Set A/B): `course_level IN` {intro/general undergrad, intermediate undergrad,
non-degree credit, uncategorized} AND `sector` = the 6 real teaching sectors (IPEDS 1–6).
"Required" = **`filter_include`** (inferred is_required, #1). Magnitudes **post-#36 supply
exclusion**: A=**2,521,847** / B=**131,314** (4,044 supply-only-required sections moved A→B; total
2,653,161 conserved). Enrollment fill reproduces cards 133/134 exactly (own=1,825,095; raw 52.8M →
assigned 74.0M; 28.6% imputed; 0 unassigned in scope). All 6 `master_section` DQ invariants = 0.

### Done in this pass (#32 / #36 integration / #39)

Landed via one Metabase stop-window rebuild (`.temp/rebuild_enrichment.sh`: `2_oer_classification.sql`
→ `4_merged_records.sql`, ~5.5 min). Decisions taken: enrollment medians use the **scope reference
population per period** (reproduces the reviewed cards exactly); supply exclusion is **in-place** on
counts/costs with `is_supply`/`supply_count` audit columns; classification spans **all 2024+** titles
(2,481 supply ISBNs / 87.4k catalog rows). Adversarially reviewed before the write — 2 findings fixed
(`enriched AS MATERIALIZED`; `master_course_material` supply exclusion), 1 filed as **#40**.

### Held / pending decisions (do NOT start without sign-off)

- **#40** (filed this pass) — `has_required` contamination: a supply-only "required" item keeps
  `has_required=TRUE`, misbucketing a co-listed real textbook as optional (59 Fall-2025 scope
  sections). Pre-existing; a proper fix touches the required-inference core (issue #1/#34) on both
  the catalog and pricing sides → its own issue + review. Not a regression from this pass.
- **Hypothesis test** (enrollment-weighted / same-item cost across classes) — HELD; documented as
  a proposal in Notion. **Now unblocked** (#32 + #36 landed): reads `master_section.enrollment_assigned`
  directly. Awaiting go-ahead to run.

**Enrichment principle (important):** derived/enriched columns belong **on `master_section`**,
NOT in new downstream tables. Downstream artifacts (like the #38 view) only *project/filter*.
That's why #32/#36 are framed as new master_section columns, not side tables.

### Documentation surface — Notion (living)

Page **"26.06.26 · Fall 2025 Subsets A/B (BMG)"** = `38bd9fdd-1a1a-81f9-b094-c13ba9cfbedf`
(under the "📁 CommodoreSQL" project page). Sub-page **"Supply keyword lists (#36)"**. Update it
at each major step + wrap, autonomously, as long as decisions/assumptions/tradeoffs are captured.

## How to run things

**Read-only ad-hoc query** (coexists with Metabase's read lock — always bound memory):
```bash
duckdb -readonly duckdb/commodore.duckdb <<'SQL'
SET memory_limit='8GB'; SET threads=4;
SELECT ... ;
SQL
```

**Full pipeline** (`scripts/run_sql.sh`, stages skippable via `NO_IMPORT`/`NO_EDA`/`NO_EXPORT`).
Single file: `.temp/run_one.sh <file.sql>` (envsubst + duckdb). `${CONFIG}` = `sql/config.sql`.

**Writes to the DB require stopping Metabase** (it holds the file lock):
```bash
docker stop metabase
duckdb duckdb/commodore.duckdb <<'SQL'  ... write ...  SQL
docker start metabase          # existing container; ./metabase.sh rebuilds/recreates it
# then re-sync Metabase's schema so new tables/views appear:
curl -s -X POST "$METABASE_URL/api/database/2/sync_schema" -H "X-API-Key: $METABASE_API_KEY"
```

**Metabase question/dashboard sync** (config-as-code):
```bash
set -o allexport; source scripts/dot.env; set +o allexport   # gets METABASE_API_KEY
python3 metabase/sync.py            # creates/updates cards; IDs tracked in metabase/ids.json (keyed by filename stem)
python3 metabase/sync.py --dry-run  # preview
```
DB id = **2**. Questions = SQL + `-- name:`/`-- display:`/`-- description:` frontmatter.

**Supply classifier / subset exports** (re-runnable, read-only, output to gitignored `output/`):
```bash
scripts/classify_supplies.sh          # -> output/fall2025_supply_isbns.parquet + prevalence/impact
scripts/export_fall2025_subsets.sh    # -> output/fall2025_set{A,B}_*.parquet
```

## Gotchas (bite people)

- `DUCKDB` in `dot.env` is `"duckdb -bail"` (binary + flag) — expand **unquoted** so it word-splits.
- Blank `ISBN13` is empty-string `''`, not NULL (~54% of catalog). Canada = **`state='CAN'`**
  (single code, blank-institution; IPEDS is US-only).
- `period_sortable='2025-4'` = Fall 2025 (N: 1=Winter 2=Spring 3=Summer 4=Fall).
- `price_avg` / `*_cost_avg` = **`(min+max)/2`**, NOT an arithmetic mean (legacy). Label wherever surfaced.
- `master_section` is a **materialized TABLE** (window + LIST aggs too costly as a view). Cheap to
  `SELECT *`; don't rebuild casually (heavy). It carries institution enrichment + coverage +
  `has_enrollment_*` + cost columns already.
- `seats_taken` = 9999 is an invalid sentinel; `pricing` sentinel prices ≥ 9999 are nulled in `pricing_wide`.
- A heavy `SELECT *` on an **un-materialized** view once crashed the box — bound memory on big scans.

## Pointers

- `SCHEMA.md` — pipeline stages, tables, lineage diagram. `schema.dbml` — full column defs (dbdiagram.io).
- `CLAUDE.md` — naming standards + gotchas. `260529-DECISIONS.md` — historical design decisions (May 2026).
- GitHub Issues #1–#39 are the backlog/tracker (TODO.md was removed — its items are #19–#22).
