# HANDOFF — CommodoreSQL / BMG cost-data analysis

> 🔗 **Living Notion build-log:** https://app.notion.com/p/38bd9fdd1a1a81f9b094c13ba9cfbedf

Pickup context as of **2026-08-29**. Read this first, then `SCHEMA.md` (data model) and
`CLAUDE.md` (conventions). Work tracking is **GitHub Issues + Projects board**, not this file.

## What this repo is

A DuckDB pipeline (`duckdb/commodore.duckdb`, ~71 GB) that joins course-catalog data
(~103M rows) with IPEDS, bookstore pricing, and opt-out/panel lists, plus a
**Metabase config-as-code** reporting layer (`metabase/`) and a GitHub Projects board.

- Branch: **`cmm-spring-2026`**; PR **#62** targets `main`.
- Board lifecycle: Todo → On Deck → In Progress → **Review** → Done. **Review = human
  review**; the implementing agent sets Review only after self-validating, and the human owns
  Review → Done.

## Current focus — August 2026 CMM refresh

- Source communications and extracted XLSX/DOCX/image content are under `comms/`; the
  release-facing pipeline contract is `CMM-ETL.md`.
- **#69 pricing ownership cleanup:** `pricing_historical` remains an indexed, deduplicated
  source-owned snapshot after import, `1b_section_filter.sql` builds only catalog
  `section_book_status`, and `pricing_wide` contains only pricing source/provenance and price
  transformations. Required inference, OER/IA, and IPEDS enrichment stay catalog-owned; the old
  pricing-enrichment step and required-only pricing view are gone. `2d_data_quality.sql`
  performs exact cross-source comparisons without mutating pricing. `course_materials` keeps the
  canonical catalog item spine; `material_costs` is its current exact section×ISBN LEFT pricing
  enrichment. Matching evidence and any
  future join-key design are centralized in the
  [issue #21 limitation](CMM-ETL.md#current-limitation--pricing-to-catalog-section-matching-issue-21).
- **#64 lineage correction:** `SCHEMA.md` now separates exact `run_sql.sh` execution order from
  data-dependency lineage, carries the current automatic and standalone export layer through to
  concrete files, and explicitly labels standalone canonical Course Materials exports. `CMM-ETL.md` owns the linked
  filter/derived-field semantics; pending sources remain outside the executable path. The alternate
  recursive Parquet wrapper now resolves repo-relative config/temp/output paths and fails if any
  export fails.
- `course_materials` is the first canonical materialized one-row-per-(period, section, ISBN) item
  table; `material_costs` is the canonical Use item table with pricing enrichment. `section_enrollment`
  owns exact assigned enrollment. `section_cost` and `master_isbn`
  consume `material_costs`; `master_section`, `master_institution`, and `master_isbn` are the
  three canonical materialized per-term release tables; `material_costs` is exported alongside
  them. The two rollup queries are in
  `scripts/sql/models/`, combined export
  wrappers in `scripts/sql/exports/`, and all four exported tables are release-split by
  `scripts/export_cmm_masters.sh`; institution/ISBN are Metabase Models 170/171. The rebuilt
  models contain 14,336 material-bearing institution-term rows and 1,713,368 ISBN-term rows;
  Fall 2025 has 2,216 and 335,157 respectively. New-input readiness remains pending #51.
- **#65 canonical Course Materials flow IMPLEMENTED AND VALIDATED** —
  `comprehensive_data` remains exactly the enriched, normalized BMG source-row table and the
  source for mailing, faculty, and raw DQ. Raw `panel` history is retained; `panel_email` is the
  one-row-per-email lookup used for enrichment, preventing response-history multiplication.
  `2b_course_materials.sql` now builds `section_enrollment` and the first canonical processed
  `course_materials` table at one `(period_sortable, section_id, isbn13)`, including one NULL-ISBN
  audit row per section when present, source/variant/conflict fields, and canonical
  `post_2024`/`use`/`no_use`/`canada` views. `material_costs` is only the LEFT pricing enrichment
  of `course_materials_use`; the established Material Costs and Master Section baselines remain
  12,806,060 and 6,983,049 respectively. The rebuilt `comprehensive_data` and
  `course_materials` counts are 102,885,609 and 96,663,781, with exact raw-row conservation.
  Master Section's excluded-item sidecar reads canonical
  `course_materials`; complete audits remain on `comprehensive_data` and `section_enrollment`.
  All nine raw→canonical→Material Costs reconciliation rows match. A fresh temporary Fall 2025
  run of the standalone exporter produced all five 99-column files with database-identical row
  counts; the pre-existing dated release files were deliberately not overwritten.
- Deterministic 10% work uses `sample10_section_ids` and rule
  `md5-prefix64-mod10-v1`; join this membership table at every stage. Do not reintroduce
  independent `hash()`/Bernoulli predicates or multiply distinct institution/ISBN domains by ten.
  `37_sample10_reconciliation.sql` emits 192 checks, including 176 additive checks: zero fail and
  one sparse source cell is explicitly not testable. Sample membership remains 2,359,278 sections
  from the complete `section_enrollment` population with the pre-rebuild hash fingerprint
  unchanged; the material-bearing Master Section intersection is 698,578 rows.
  The 25-institution fixture remains blocked on the promised ID list.
- The current local source/DB ends at `2025-4`. Spring 2026 catalog/pricing, `cmm_discipline`,
  updated mailing history, 25 IPEDS IDs/sample pricing, updated IPEDS, external pricing, and
  campus IA inputs are not present locally; do not invent schemas or substitute old snapshots.
- The expected current material-cost baseline is **12,806,060** canonical Use rows. This is a
  refresh baseline, not evidence that Spring 2026 or `cmm_discipline` has landed.
- Existing gitignored release artifacts date to 2026-08-27 and predate the #65 rebuild; regenerate
  them from the current database before release rather than treating those files as validation
  evidence. Their prior counts were the 698,578-row Master Section sample intersection and 2025-4
  Master Section (1,509,634), Master Institution (2,216), Master ISBN (335,157), and Material Costs
  (2,754,111).
  Metabase config and schema were synced on 2026-08-29, the local service reports healthy, and
  the lineage, bookstore-pair, and release-model cards execute successfully. The #61 migration
  now routes release-facing cards through canonical item/material-section models, labels raw/DQ
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
| #35 | A/B subsets (Set A = ≥1 required, Set B = optional-only), 5 tallies, enrollment assignment | Metabase cards **126/127**, **128–132**, **133/134**; questions `35`,`37`–`45`; `scripts/export_fall2025_subsets.sh` → Parquet |
| #37 | Master ISBN dataset (one row per ISBN13×Title×Author×Format×FormatType) | card **157**, question `46_master_isbn_fall2025.sql` |
| #38 | `master_section` US intro/intermediate required VIEW | DB view **`master_section_us_intro_fall2025`** (in `4_merged_records.sql`), GUI-queryable in Metabase |
| #36 | Supply-vs-course-material ISBN classifier + **model integration** | `scripts/sql/lookups/supply_keywords.tsv` (97 incl + 26 excl), `1a_supply_classification.sql`; `is_supply`/`supply_category` on `comprehensive_data`, `is_supply`/`supply_count` on `master_section` |
| #32 | **Persisted** `enrollment_assigned`/`enrollment_source` | `section_enrollment` owns the exact per-section assignment (per-period medians over the scope reference population); `master_section` consumes it and cards 133/134 project the columns |
| #39 | Metabase **Models** (`master_section` 158, US-intro-scope 159) + **3 dashboards** (Overview 18, Cost-hypothesis 16, Enrollment-DQ 17) | `metabase/models/*.sql`, `metabase/dashboards/bmg_*.json`, `sync.py` model support |

Scope filter (Set A/B): `course_level IN` {intro/general undergrad, intermediate undergrad,
non-degree credit, uncategorized} AND `sector` = the 6 real teaching sectors (IPEDS 1–6).
"Required" = **`is_required_inferred`** (inferred is_required, #1; renamed from `filter_include`, #34).
Current material-bearing magnitudes under the **#58 canonical Use** contract:
A=**858,147** / B=**126,441 optional-only**, for **984,588** sections. Assigned enrollment is
**29,040,503**; **29.22% of assigned enrollment** derives from imputed section values,
**33.30% of sections** are imputed, and **23.27%** use the `class_median` rung.
The former 2,653,161-section denominator and its 1,795,014-row no-required Set B included
no-adoption/full-spine sections and are historical, not current release values. All current merged
model and release reconciliation checks report zero violations.

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

- **#34 DONE** — renamed `filter_include` → `is_required_inferred` across the then-current model.
  The later #69 ownership cleanup removed that inferred catalog field from both pricing tables;
  it remains on `comprehensive_data` and downstream canonical material models.
- **#41 RESOLVED** — audit: ~90% of pseudo-SKU required rows are **legitimate** access codes
  (Cengage/MyLab) — kept. Two precision-verified gaps folded into the classifier via
  `supply_keywords.tsv`: `eyewear` (science_lab) + 12 explicit "no material required" phrases
  (`placeholder_no_material` category). Shifted ~1,747 scope sections A→B (Set A 2,521,855→**2,520,108**,
  B→**133,053**). Both #34+#41 landed in one window (`.temp/rebuild_3441.sh`); adversarial review clean;
  invariants 0; enrollment unchanged. The remaining #41 DQ residual (431,363 rows) is the legitimate
  access-code floor.

### Held / pending decisions (do NOT start without sign-off)

- The BMG initial-analysis backlog #32/#34/#35/#36/#37/#38/#39/#40/#41 is complete and marked
  Done, and the enrollment-weighted hypothesis test has been run. **#26 remains a held PI
  decision**: confirm whether “owned cost” means the buy-priced subset and approve its release
  label before changing that contract.

**Ownership principle (important):** `comprehensive_data` owns enriched/raw source-row data and
row-level flags; `section_enrollment` owns exact assigned enrollment; `course_materials` owns the
canonical processed item spine and audit/conflict evidence; and `material_costs`
owns only pricing enrichment of canonical Use items. `master_section` is exactly the
material-bearing section rollup, enriched from `section_enrollment`, with price/cost fields from
`material_costs` via `section_cost`; downstream views project/filter these canonical tables. The
complete 2024+ section population remains independently available in `section_enrollment`.

### Documentation surface — Notion

The Notion project home is [**Courses & Materials**](https://app.notion.com/p/sqrlly/CommodoreSQL-23ad9fdd1a1a81768f4ec604dfc5639f).
Its three Overview destinations are:

- **Data Lineage** — `3cbd9fdd-1a1a-8086-b499-daa92a739c9f` — sourced from the tagged
  `SCHEMA.md`.
- **Data Dictionary** — `3cbd9fdd-1a1a-8082-b697-ca7f5ef1d6ed` — sourced from the tagged
  `MASTER-SECTION-DICTIONARY.md`.
- **Dashboards & Reports** — `3cbd9fdd-1a1a-80ee-884d-f4c7003aaf44` — sourced from the tagged
  `DASHBOARDS-REPORTS.md` inventory.

The [**CMM ETL Contract**](https://app.notion.com/p/CMM-ETL-Contract-3cbd9fdd1a1a81d893effd579a76812b)
page — `3cbd9fdd-1a1a-81d8-93ef-fd579a76812b` — is a synced child of **Data Lineage**, sourced
from the tagged `CMM-ETL.md`; it is not a fourth Overview peer.
Only those four explicitly tagged documents are intended sync inputs; repo-only guidance,
historical notes, and `comms/` source captures are not automatic inputs. Preview the explicit sync
(read-only by default):

```bash
python3 scripts/sync_notion_docs.py SCHEMA.md CMM-ETL.md MASTER-SECTION-DICTIONARY.md DASHBOARDS-REPORTS.md
```

Add `--apply` to push. Apply is non-transactional, so each document update must be treated
independently. The initial 2026-08-29 push was read back successfully with all four page titles,
the CMM ETL Contract child under Data Lineage, all Overview-block parents unchanged, and no
truncated or unknown blocks. The legacy build-log
page **"26.06.26 · Fall 2025 Subsets A/B (BMG)"**
(`38bd9fdd-1a1a-81f9-b094-c13ba9cfbedf`) remains linked as historical context, including its
**"Supply keyword lists (#36)"** sub-page.

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
The 6.98M-row material-bearing `master_section` rebuild was validated with
`MEM_LIMIT=16GB NUM_THREADS=1`; its
narrow staged TEMP aggregates peaked at about 17GB resident memory and avoid the prior 89.5GB OOM.
The deterministic production #65 `2b_course_materials.sql` run completed in 51m32s at the same
bound. It peaked at about 17GB resident memory and an observed 245GiB of DuckDB spill before merging the
96,663,781-row canonical table; allow substantial local temp space for a full rebuild.

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
scripts/export_cmm_masters.sh 2025-4  # -> four dated Master Section/Institution/ISBN/Material Costs CSVs
scripts/export_course_materials.sh 20250828 2025-4 # -> five dated canonical Course Materials CSVs
```

The Course Materials exporter stages all five outputs and refuses to overwrite existing files.

## Gotchas (bite people)

- `DUCKDB` in `dot.env` is `"duckdb -bail"` (binary + flag) — expand **unquoted** so it word-splits.
- Blank `ISBN13` is imported as NULL (~54% of catalog; zero empty strings in the current DB).
  Canada = **`state='CAN'`**
  (single code, blank-institution; IPEDS is US-only).
- `period_sortable='2025-4'` = Fall 2025 (N: 1=Winter 2=Spring 3=Summer 4=Fall).
- `price_avg` / `*_cost_avg` = **`(min+max)/2`**, NOT an arithmetic mean (legacy). Label wherever surfaced.
- `master_section` is a **materialized TABLE** (window + LIST aggs too costly as a view). Cheap to
  `SELECT *`; don't rebuild casually (heavy). It carries institution enrichment + coverage +
  `has_enrollment_*`; exact assigned enrollment comes from `section_enrollment`, and price/cost
  columns roll through `material_costs` → `section_cost`. Its population is material-bearing;
  query `section_enrollment` for no-adoption and other full-section denominators.
- `seats_taken` = 9999 is an invalid sentinel; `pricing` sentinel prices ≥ 9999 are nulled in `pricing_wide`.
- Catalog duplicates collapse at `(period_sortable, section_id, isbn13)` for `material_costs`;
  variant counts/conflict signals remain available for DQ. Pricing duplicates collapse at the
  documented historical pricing key, with rental-term multiplicity retained in raw history.
  Pricing tables are source-owned; do not write catalog classifications onto them.
- `scripts/sql/exports/41_material_costs_reconciliation.sql` is the raw→canonical→cost audit;
  its detailed pricing-match limitation is documented only in the issue #21 section of
  `CMM-ETL.md`.
- A heavy `SELECT *` on an **un-materialized** view once crashed the box — bound memory on big scans.

## Pointers

- `SCHEMA.md` — pipeline stages, tables, lineage diagram. `schema.dbml` — full column defs (dbdiagram.io).
- `BMG-SUMMARY.md` — decisions / outputs (grouped) / review notes for the BMG analysis (the reference).
- `BMG-2026-07-09-CALL.md` — same format for the 2026-07-09 call round (#42–#49: analyses + index fix).
- `CLAUDE.md` — naming standards + gotchas. `260529-DECISIONS.md` — historical design decisions (May 2026).
- GitHub Issues and Project 2 are the current backlog/tracker; this handoff records implementation
  context, not authoritative issue status.
