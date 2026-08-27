# HANDOFF — CommodoreSQL / BMG cost-data analysis

> 🔗 **Living Notion build-log:** https://app.notion.com/p/38bd9fdd1a1a81f9b094c13ba9cfbedf

Pickup context as of **2026-08-27**. Read this first, then `SCHEMA.md` (data model) and
`CLAUDE.md` (conventions). Work tracking is **GitHub Issues + Projects board**, not this file.

## What this repo is

A DuckDB pipeline (`duckdb/commodore.duckdb`, ~71 GB) that joins course-catalog data
(~103M rows) with IPEDS, bookstore pricing, and opt-out/panel lists, plus a
**Metabase config-as-code** reporting layer (`metabase/`) and a GitHub Projects board.

- Branch: **`cmm-spring-2026`** (push to it, **no PR** — team convention).
- Board lifecycle: Todo → On Deck → In Progress → **Review** → Done. **Review = human
  review**; the implementing agent sets Review only after self-validating, and the human owns
  Review → Done.

## Current focus — August 2026 CMM refresh

- Source communications and extracted XLSX/DOCX/image content are under `comms/`; the
  release-facing pipeline contract is `CMM-ETL.md`.
- `master_section`, `master_institution`, and `master_isbn` are the three canonical materialized
  per-term release tables. The two rollup queries are in `scripts/sql/models/`, combined export
  wrappers in `scripts/sql/exports/`, and all three are release-split by
  `scripts/export_cmm_masters.sh`; institution/ISBN are Metabase Models 170/171. The rebuilt
  models contain 15,698 institution-term rows and 1,713,368 ISBN-term rows; Fall 2025 has
  2,373 and 335,157 respectively. New-input readiness remains pending #51.
- **#58 IMPLEMENTED AND REBUILT** — `comprehensive_data` now owns non-null row flags
  and the exact post-2024 Use/NoUse partition. Use excludes Canada, NULL ISBN, supplies,
  `*No Book Details*`, and explicit no-material placeholders. `master_section` deliberately keeps
  the complete valid 2024+ section/enrollment spine (the #20 retention decision), while all
  material/publisher/OER/IA/coverage/cost aggregates, `master_course_material`, and `master_isbn`
  use the canonical flag. Supply audit remains all-row (#36); legitimate pseudo-SKUs remain
  eligible unless the existing classifier catches them (#41). Observed counts are 31,506,574
  post-2024 rows = 13,650,872 Use + 17,855,702 NoUse, including 1,058,295 Canada rows. The
  23,580,550-section spine and 599,778,117 assigned-enrollment total are unchanged; `section_cost`
  has 6,983,049 Use-bearing sections and unchanged priced counts/dollar sums.
- Deterministic 10% work uses `sample10_section_ids` and rule
  `md5-prefix64-mod10-v1`; join this membership table at every stage. Do not reintroduce
  independent `hash()`/Bernoulli predicates or multiply distinct institution/ISBN domains by ten.
  `37_sample10_reconciliation.sql` emits 160 additive checks: 159 pass, 0 fail, and the single
  2024-1 no-material row is explicitly not testable because it is absent from the sample. The 16
  institution/ISBN metrics are coverage-only. Sample membership remains 2,359,278 sections with
  the pre-rebuild hash fingerprint unchanged.
  The 25-institution fixture remains blocked on the promised ID list.
- The current local source/DB ends at `2025-4`. Spring 2026 catalog/pricing, `cmm_discipline`,
  updated mailing history, 25 IPEDS IDs/sample pricing, updated IPEDS, external pricing, and
  campus IA inputs are not present locally; do not invent schemas or substitute old snapshots.
- Current gitignored release artifacts were regenerated from the rebuilt database on 2026-08-27:
  Fall 2025 Set A/B Parquets, the 2,359,278-row deterministic sample CSV.gz, and the 2025-4
  Master Section (5,007,488 rows), Master Institution (2,373), and Master ISBN (335,157) CSVs.
  Metabase config was synced afterward and the local service reports healthy. The #61 migration
  now routes release-facing cards through canonical Use/full-spine models, labels raw/DQ
  exceptions explicitly, and binds both report cards directly to `master_section` dimensions.
- The actionable current-data portion of #59 now has a complete 66-column Master Section release
  dictionary (`MASTER-SECTION-DICTIONARY.md`) and an exact cross-model reconciliation export
  (`38_cmm_release_reconciliation.sql`) plus a separately bounded exact-key audit (`39_...`);
  all 144 cross-model checks and all 8 term key sets match exactly in the rebuilt database.
  Spring 2026 and the shared 25-institution rerun remain external dependencies in #51/#60.

## Prior focus — BMG grant cost analysis (Bay View Analytics / Jeff Seaman)

Fixed initial-analysis scope: **Fall 2025** (`period_sortable='2025-4'`). Everything is built
**re-runnable** — the supply exclusion (#36), enrollment fill (#32), `has_required` fix (#40), the
`is_required_inferred` rename (#34), and the #41 fold-in have all landed on `master_section`.

### Completed initial-analysis work

| # | Deliverable | Where |
|---|---|---|
| #35 | A/B subsets (Set A = ≥1 required, Set B = none), 5 tallies, enrollment assignment | Metabase cards **126/127**, **128–132**, **133/134**; questions `35`,`37`–`45`; `scripts/export_fall2025_subsets.sh` → Parquet |
| #37 | Master ISBN dataset (one row per ISBN13×Title×Author×Format×FormatType) | card **157**, question `46_master_isbn_fall2025.sql` |
| #38 | `master_section` US intro/intermediate required VIEW | DB view **`master_section_us_intro_fall2025`** (in `4_merged_records.sql`), GUI-queryable in Metabase |
| #36 | Supply-vs-course-material ISBN classifier + **model integration** | `scripts/sql/lookups/supply_keywords.tsv` (97 incl + 26 excl), `1a_supply_classification.sql`; `is_supply`/`supply_category` on `comprehensive_data`, `is_supply`/`supply_count` on `master_section` |
| #32 | **Persisted** `enrollment_assigned`/`enrollment_source` on `master_section` | `4_merged_records.sql` (per-period medians over the scope reference population); cards 133/134 now project the columns |
| #39 | Metabase **Models** (`master_section` 158, US-intro-scope 159) + **3 dashboards** (Overview 18, Cost-hypothesis 16, Enrollment-DQ 17) | `metabase/models/*.sql`, `metabase/dashboards/bmg_*.json`, `sync.py` model support |

Scope filter (Set A/B): `course_level IN` {intro/general undergrad, intermediate undergrad,
non-degree credit, uncategorized} AND `sector` = the 6 real teaching sectors (IPEDS 1–6).
"Required" = **`is_required_inferred`** (inferred is_required, #1; renamed from `filter_include`, #34).
Current magnitudes under the **#58 canonical Use** material contract: A=**858,147** /
B=**1,795,014** (the full 2,653,161-section scope is conserved). The prior post-#36/#40/#41
split was 2,520,108 / 133,053.
Enrollment fill reproduces cards 133/134 exactly (own=1,825,095; raw 52.8M → assigned 74.0M; 28.6%
imputed; 0 unassigned in scope). All nine merged-model reconciliation checks report 0 violations
(seven `master_section`, two `master_course`).

### Done in this pass (#32 / #36 integration / #39)

Landed via one Metabase stop-window rebuild (`.temp/rebuild_enrichment.sh`: `2_oer_classification.sql`
→ `4_merged_records.sql`, ~5.5 min). Decisions taken: enrollment medians use the **scope reference
population per period** (reproduces the reviewed cards exactly); supply exclusion is **in-place** on
counts/costs with `is_supply`/`supply_count` audit columns; classification spans **all 2024+** titles
(2,481 supply ISBNs / 87.4k catalog rows). Adversarially reviewed before the write — 2 findings fixed
(`enriched AS MATERIALIZED`; `master_course_material` supply exclusion), 1 filed as **#40**.

### Done in a later pass (#40 fix + hypothesis test)

- **#40 FIXED** — `has_required` is now **supply-aware** (`BOOL_OR(book_status='required' AND NOT
  is_supply)`). Supply classification moved to a new upstream stage **`1a_supply_classification.sql`**
  (so `1b_` can consult it); `1b_` idempotency fixed (`ADD COLUMN IF NOT EXISTS` + reset). Recovered
  8 BMG-scope sections (B→A: Set A 2,521,855 / B 131,306; +6 to the #38 view); enrollment fill
  unchanged; all `master_section` DQ invariants 0. Landed via `.temp/rebuild_40.sh` (1a→1b→2→
  pricing_wide patch→4→2d; the patch avoids the heavy 2c_ pivot). Reviewed pre-write; surfaced **#41**.
- **Cost hypothesis test** — RUN (cards 160/161, dashboard 16). Public 2yr ~$149/student vs Public
  4yr ~$114 (+31%, robust); driven by course-mix, not same-item price (~$2). See Notion Step 6.

### Done in the latest pass (#34 rename + #41 audit)

- **#34 DONE** — renamed `filter_include` → `is_required_inferred` model-wide (6 pipeline SQL, 18
  Metabase questions, 2 dashboards, docs; word-boundary swap, stems preserved). DB: `ALTER RENAME
  COLUMN` on `pricing_historical`/`pricing_wide` (drop/recreate the 3 pricing indexes + the
  `pricing_wide_filtered` view — DuckDB blocks structural ALTER while indexes exist);
  `comprehensive_data` renamed via its `2_` rebuild. Semantics-preserving; `260529-DECISIONS.md` left
  on the old name (frozen record).
- **#41 RESOLVED** — audit: ~90% of pseudo-SKU required rows are **legitimate** access codes
  (Cengage/MyLab) — kept. Two precision-verified gaps folded into the classifier via
  `supply_keywords.tsv`: `eyewear` (science_lab) + 12 explicit "no material required" phrases
  (`placeholder_no_material` category). Shifted ~1,747 scope sections A→B (Set A 2,521,855→**2,520,108**,
  B→**133,053**). Both #34+#41 landed in one window (`.temp/rebuild_3441.sh`); adversarial review clean;
  invariants 0; enrollment unchanged. The remaining #41 DQ residual (431,363 rows) is the legitimate
  access-code floor.

### Held / pending decisions (do NOT start without sign-off)

- _(none open — the BMG initial-analysis backlog #32/#34/#35/#36/#37/#38/#39/#40/#41 is complete
  and marked Done. The enrollment-weighted hypothesis test has been run.)_

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
`MEM_LIMIT` and `NUM_THREADS` supplied in the process environment override `scripts/dot.env`.
The 23.6M-row `master_section` rebuild was validated with `MEM_LIMIT=16GB NUM_THREADS=1`; its
narrow staged TEMP aggregates peaked at about 17GB resident memory and avoid the prior 89.5GB OOM.

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

**Supply classifier / analysis exports** (re-runnable, read-only, output to gitignored `output/`):
```bash
scripts/classify_supplies.sh          # -> output/fall2025_supply_isbns.parquet + prevalence/impact
scripts/export_fall2025_subsets.sh    # -> output/fall2025_set{A,B}_*.parquet
scripts/export_cmm_masters.sh 2025-4  # -> output/cmm/master_{section,institution,isbn}_2025_4_<date>.csv
```

## Gotchas (bite people)

- `DUCKDB` in `dot.env` is `"duckdb -bail"` (binary + flag) — expand **unquoted** so it word-splits.
- Blank `ISBN13` is imported as NULL (~54% of catalog; zero empty strings in the current DB).
  Canada = **`state='CAN'`**
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
- `BMG-SUMMARY.md` — decisions / outputs (grouped) / review notes for the BMG analysis (the reference).
- `BMG-2026-07-09-CALL.md` — same format for the 2026-07-09 call round (#42–#49: analyses + index fix).
- `CLAUDE.md` — naming standards + gotchas. `260529-DECISIONS.md` — historical design decisions (May 2026).
- GitHub Issues #1–#41 are the backlog/tracker (TODO.md was removed — its items are #19–#22).
