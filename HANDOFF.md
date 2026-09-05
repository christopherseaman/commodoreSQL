# HANDOFF — CommodoreSQL

State: 2026-09-04. Backlog: GitHub Issues / Project 2.

## Repository state

- Branch: **`cmm-spring-2026`**
- PR: [#62](https://github.com/christopherseaman/commodoreSQL/pull/62), open/non-draft.
- The live database remains at the pre-#80 baseline; current branch SQL is newer.
- Inputs and `duckdb/commodore.duckdb` end at Fall 2025 (`2025-4`).
- Spring 2026 and pending lookups remain absent.

## Resume here: #86 consolidation

Validated implementation checkpoint: `43e2f8e`; pushed on the branch above.
No consolidation code is started. Clean-context subagents completed read-only
build/consumer audits; their findings are captured below. Safe to resume without chat history.

**Target:** one persisted `course_material`; temporary enrichment followed by the
existing canonical grouping. Keep the imported catalog for source-row consumers.
Do not replace `comprehensive_data` with another permanent enriched view or macro.
Both existing relations retain NoUse/Canada/supplies/placeholders; their distinction
is source-row versus item grain, not those populations.

| Work owner | Boundaries / acceptance |
|---|---|
| Build | Combine `scripts/sql/2_oer_classification.sql` and `2b_course_material.sql` into one connection/stage; each runner entry currently opens a separate connection. Update `run_sql.sh`, retired-relation cleanup, and actual-SQL fixtures. Preserve canonical keys, NULL-ISBN groups, counts/conflicts, assignment, and repeated section audits. |
| Consumers | Reroute `2d_data_quality.sql`, the full-population diagnostic in `4_merged_records.sql`, exports `01/30/37/41`, and `scripts/classify_supplies.sh`. Audit Metabase questions `01/03/46/51/57/58/61/62/68` and field bindings `57/68`; preserve report IDs and source-row denominators. |
| Metadata | After SQL contracts settle, update `schema.dbml`, generators/dictionaries, ETL/flow/report docs, manifest, and Notion. Preserve surviving page IDs; verify external field tables. |
| Reviewer | Independently challenge grain, duplicate/contact conservation, mixed requiredness, complete-section coverage, and replay before declaring staged implementation complete. |

Critical distinctions:

- Canonical `BOOL_OR` flags cannot replace source-row requiredness on mixed keys.
  Recompute narrow source predicates where needed; avoid duplicating full enrichment.
- Faculty export `30` needs raw catalog fields only. ISBN variability `61/62` also
  needs source detail; representative item metadata cannot reconstruct it.
- Complete-section reports can use deduplicated **all** `course_material` sections,
  including NULL-ISBN/NoUse groups, with inherited enrollment context. Prove key and
  value parity; do not filter to Use or put IPEDS assignment back into the helper.
- Keep invalid-key DQ on raw catalog; use NULL-safe ISBN equality where required.
- Keep exact pricing joins, the shared newest-12-term window, and provisional master
  definitions unchanged. No new source assumptions or contact-filter changes.

Execution limits: no full/live rebuild, live Metabase publication, or release of stale
`output/`. Use isolated fixtures; no new branch, source-capture edits, or descendant agents.
Delegate with `fork_turns: "none"`, explicit owned paths, allowed actions, stop conditions,
and expected results. Parent owns integration, ticket updates, and publication.

Validation: `python3 -m unittest discover -s scripts -p 'test_*.py'`; standalone
`test_legacy_cleanup.py` / `test_mailing_periods.py`; both document generators' `--check`;
diagram renders; Metabase `--dry-run` with configured environment. Add a real DQ fixture
and assert no persisted `comprehensive_data` after build/replay. Current 64-test evidence
does not validate the future consolidation or establish full-data parity.

Notion checkpoint: 40 pages synced; 32 five-column relation tables / 1,231 fields
externally verified. `panel` dictionary is recoverably trashed. Use `NOTION_KEYRING=0`
and manifest preflight before applying changes; `HANDOFF.md` itself is repo-only.

## Current implementation

- `master_material`: canonical Use items LEFT-enriched by exact section × ISBN pricing.
- `section_enrollment`: catalog-only section enrollment/seats and sibling signals; assignment happens inside `comprehensive_data`.
- `sample_material_10pct`: direct stable section-hash sample of `master_material`.
- `master_section`: all values derive from `master_material`, including inherited audits and modal bookstore URL.
- `master_course`, `master_institution`: provisional Release outputs; definitions pending.
- `current_mailing`: Master contacts in the latest 12 catalog terms, history-enriched, minus opt-outs.
- `course_material_recent`: same 12-term window; `is_recent` replaces the fixed-year flag. Classification and enrollment cover admitted older terms.
- `panel_email`: sole persisted history import; raw import staging is temporary.

[Flow](CMM-DATA-FLOW.md) · [ETL rules](CMM-ETL.md) · [Dictionary](DATA-DICTIONARY.md)

Current branch checks: 64 automated tests plus standalone cleanup/mailing checks pass.
Isolated actual-SQL fixtures cover enrollment, requiredness, canonical grain, costs,
master rollups, exact sample membership, release reconciliations, and cleanup/replay.
They also exercise inherited audit counts, section/institution URL selection,
complete-spine report totals, and report term-filter binding.
Shared-window fixtures cover admission/expiry, NULL/duplicate terms, pre-2024
classification/enrollment, and matching material/mailing windows. Panel import
tests verify deduplication and that raw staging is not persisted.
All five diagrams render; generated dictionaries/report inventory match their sources.
These checks do not establish full-data parity. The rolling window intentionally
changes the historical fixed-2024+ population; full-data term impacts remain unmeasured.

## Live pre-change baseline

The last full rebuild predates #80/#81/#83/#84. Its raw → canonical → release
reconciliation passed and remains the comparison baseline, not proof of the staged SQL:

- `comprehensive_data`: **102,885,609** enriched source rows
- `course_materials` (staged: `course_material`): **96,663,781** canonical groups/audit rows
- `material_costs` (staged: `master_material`): **12,806,060** canonical Use items
- `master_section`: **6,983,049** material-bearing sections
- Fall 2025: **2,754,111** Material Costs, **1,509,634** Master Section,
  **2,216** Master Institution, and **335,157** Master ISBN rows
- 10% material sample definition: **1,282,423** items, **698,578** material-bearing sections,
  no NULL/duplicate keys, and exact key parity with sampled `course_material_use`
- Raw conservation, release/key-set, price-cell, mailing, and partition checks passed in that rebuild.

Bounded read-only checks of the staged expressions against that snapshot found:

- Catalog and prior Master produce the same 12-period set. Each yields **1,411,582**
  Master contacts before opt-outs and **1,374,828** Working contacts after opt-outs.
- Direct `sample_material_10pct` hashing reproduces **1,282,423** items and **698,578**
  material-bearing sections with zero key difference from the retired helper join.
- Direct `master_material` cost aggregation matches all ten existing section cost fields for
  **6,983,049** sections; release reconciliation reports zero differences in every term.
- The direct `master_course` rollup preserves **3,444,030** keys. Decimal-equivalent
  averages differ only by floating aggregation order (maximum absolute difference
  **1.14e-12**); MIN/MAX values are unchanged.

## Next release

1. Resolve remaining scope/definition decisions and review PR #62.
2. Obtain pending inputs; validate schemas/terms; update `scripts/dot.env`.
3. Once the rebuild hold is lifted, stop Metabase, rebuild, validate, and restart.
4. Migrate report queries, regenerate exports, and verify keys/counts before delivery.

**Do not release `output/`: its 2026-08-27 artifacts predate the validated rebuild.**

## Open work

### Flow changes

- [#80](https://github.com/christopherseaman/commodoreSQL/issues/80) — catalog-only helper; IPEDS cohort/median work moved into enrichment; rebuild pending
- [#81](https://github.com/christopherseaman/commodoreSQL/issues/81) — direct `master_material` hash sample staged; rebuild pending
- [#85](https://github.com/christopherseaman/commodoreSQL/issues/85) — singular relation/sample naming and direct Canada export staged; live migration held
- [#86](https://github.com/christopherseaman/commodoreSQL/issues/86) — consolidate into `course_material`, rerouting source-row consumers to the catalog; implementation pending, no user clarification needed
- [#87](https://github.com/christopherseaman/commodoreSQL/issues/87) — URL carried through Master Section; final Course/Institution definitions pending
- [#88](https://github.com/christopherseaman/commodoreSQL/issues/88) — shared newest-12-term window approved and staged; full-data count effects unmeasured under rebuild hold
- [#83](https://github.com/christopherseaman/commodoreSQL/issues/83) — catalog-derived mailing window staged; bounded live-snapshot parity proven; rebuild pending
- [#84](https://github.com/christopherseaman/commodoreSQL/issues/84) — section costs folded into Master Section; rebuild pending
- [#24](https://github.com/christopherseaman/commodoreSQL/issues/24) — resolved: retain `master_course`, export 32, and Metabase card 90 for the course×term rollup; retire `master_course_material` and export 33 (no consumer; NULL publishers excluded; seats repeat across publisher/status groups).

### Reliability

- [#82](https://github.com/christopherseaman/commodoreSQL/issues/82) — implemented: all supported CLI paths force `-bail`; regression tests cover stdin, `-c`, and read-only calls

### Pricing identity: #21

[#21](https://github.com/christopherseaman/commodoreSQL/issues/21): define the source-aware
section crosswalk; preserve raw identifiers, reject ambiguous matches, and measure impacts.
Exact matching remains active. [Evidence and constraints](PRICING-CATALOG-MATCHING.md).

### External blockers

- [#23](https://github.com/christopherseaman/commodoreSQL/issues/23) — external pricing inputs and integration
- [#51](https://github.com/christopherseaman/commodoreSQL/issues/51) — Spring 2026 source drops
- [#52](https://github.com/christopherseaman/commodoreSQL/issues/52) — `cmm_discipline`
- [#56](https://github.com/christopherseaman/commodoreSQL/issues/56) — updated BVA mailing history
- [#57](https://github.com/christopherseaman/commodoreSQL/issues/57) — campus IA (`cmm_ia`)
- [#60](https://github.com/christopherseaman/commodoreSQL/issues/60) — 25 institution list and scoped outputs
- [#72](https://github.com/christopherseaman/commodoreSQL/issues/72) — bookstore-brand lookup
- [#76](https://github.com/christopherseaman/commodoreSQL/issues/76) — snapshot-retention decision

### Held decision: #26

[#26](https://github.com/christopherseaman/commodoreSQL/issues/26): PI must choose all required
materials or the current buy-priced subset and labels. Do not change it.

### Separate older backlog

Persistent DQ logging #19; Metabase organization #30; cost-driver/OER modeling #43;
advanced reporting #47; parked program/course ideas #48. All are ticketed; none blocks #86.

## Essential commands

Read-only query:

```bash
duckdb -bail -readonly duckdb/commodore.duckdb <<'SQL'
SET memory_limit='8GB'; SET threads=4;
SELECT ...;
SQL
```

Pipeline and release exports:

```bash
scripts/run_sql.sh
NO_IMPORT=1 NO_EXPORT=1 scripts/run_sql.sh
scripts/export_cmm_masters.sh 2025-4
scripts/export_course_material.sh 20260901 2025-4
```

Stop Metabase before database writes; restart afterward:

```bash
docker stop metabase
MEM_LIMIT=16GB NUM_THREADS=1 scripts/run_sql.sh
docker start metabase
```

Metabase preview: `python3 metabase/sync.py --dry-run`. Do not publish the renamed
queries until the database migration succeeds; live reports still use the old names.
