# HANDOFF — CommodoreSQL

State: 2026-09-05. Backlog: GitHub Issues / Project 2.

## Repository state

- Branch: **`cmm-spring-2026`**
- PR: [#62](https://github.com/christopherseaman/commodoreSQL/pull/62), open/non-draft.
- The full staged flow was rerun successfully on 2026-09-05; see [RERUN.md](RERUN.md) for counts, QA, and remaining issues.
- Metabase was stopped for the rebuild and restarted afterward; no live Metabase publication or external release was performed.
- Inputs and `duckdb/commodore.duckdb` end at Fall 2025 (`2025-4`).
- Spring 2026 and pending lookups remain absent.

## Latest decision and resume point

**Keep both tables. #86 is canceled and closed as not planned.**
`comprehensive_data` retains enriched source rows; `course_material` groups valid
term × section × ISBN keys and retains counts/conflicts plus NULL-ISBN audit groups.
Both retain NoUse/Canada/supplies and older terms. Their different grains are intentional.
All unfinished consolidation changes were reverted; SQL and report queries remain at
the validated `43e2f8e` implementation checkpoint. Do not resume the former consolidation plan.

[#89](https://github.com/christopherseaman/commodoreSQL/issues/89) is complete (`9cd8bd8`): checked actual staged
table dependencies against the diagram and replaces the flow explanation with Sources,
Logic (Materials, Pricing, Mailing, Release), and Samples & exports. Independent audit
found no implemented dependency mismatch; the former #86 note was stale. The rewrite
also corrects Master ISBN price-cell availability wording and the geographic lookup
description. The revised flow/schema pages are synced with verified Notion readback.

Remaining flow tickets #80/#81/#83/#84/#85/#88 have staged implementations exercised
by the full rebuild; ticket closure and external release decisions remain separate.
#87 still needs final Master Course/Institution definitions. Missing sources and other
decisions are listed below. No further flow refactor is implicitly authorized by the
documentation rewrite.

No live Metabase publication or external release; current and pre-existing `output/`
artifacts are distinguished in [RERUN.md](RERUN.md).
Use isolated fixtures. Delegate with `fork_turns: "none"` and explicit bounded context;
no descendant agents, new branch, or source-capture edits.

Notion: 40 manifest pages, 32 relation dictionaries / 1,231 fields. Surviving page IDs
are unchanged; the `comprehensive_data` dictionary is retained. Use `NOTION_KEYRING=0`
and manifest preflight before publication; `HANDOFF.md` is repo-only.

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

Current branch checks: 65 automated tests plus standalone cleanup/mailing checks pass.
Isolated actual-SQL fixtures cover enrollment, requiredness, canonical grain, costs,
master rollups, exact sample membership, release reconciliations, and cleanup/replay.
They also exercise inherited audit counts, section/institution URL selection,
complete-spine report totals, and report term-filter binding.
Shared-window fixtures cover admission/expiry, NULL/duplicate terms, pre-2024
classification/enrollment, and matching material/mailing windows. Panel import
tests verify deduplication and that raw staging is not persisted.
All five diagrams render; generated dictionaries/report inventory match their sources.
These checks do not establish parity with the pre-change baseline. The rolling window
intentionally changes the historical fixed-2024+ population; full-data impacts are recorded in [RERUN.md](RERUN.md).

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
3. Review [RERUN.md](RERUN.md), resolve non-small findings, and update ticket statuses.
4. Migrate report queries, verify keys/counts, and make an explicit external delivery decision.

**Do not release `output/` wholesale:** the 2026-09-05 exports are current, but older
artifacts remain and are listed in [RERUN.md](RERUN.md).

## Open work

### Flow changes

- [#80](https://github.com/christopherseaman/commodoreSQL/issues/80) — catalog-only helper; IPEDS cohort/median work moved into enrichment; full rebuild exercised, closure pending
- [#81](https://github.com/christopherseaman/commodoreSQL/issues/81) — direct `master_material` hash sample staged; full rebuild exercised, closure pending
- [#85](https://github.com/christopherseaman/commodoreSQL/issues/85) — singular relation/sample naming and direct Canada export staged; full rebuild exercised, release decision pending
- [#86](https://github.com/christopherseaman/commodoreSQL/issues/86) — canceled; retain source-row `comprehensive_data` and item-grain `course_material`
- [#89](https://github.com/christopherseaman/commodoreSQL/issues/89) — complete; verified staged SQL/diagram agreement and rewrote the flow explanation
- [#87](https://github.com/christopherseaman/commodoreSQL/issues/87) — URL carried through Master Section; final Course/Institution definitions pending
- [#88](https://github.com/christopherseaman/commodoreSQL/issues/88) — shared newest-12-term window approved and staged; full-data effects recorded in [RERUN.md](RERUN.md)
- [#83](https://github.com/christopherseaman/commodoreSQL/issues/83) — catalog-derived mailing window staged; bounded live-snapshot parity proven; full rebuild exercised
- [#84](https://github.com/christopherseaman/commodoreSQL/issues/84) — section costs folded into Master Section; full rebuild exercised
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
advanced reporting #47; parked program/course ideas #48. All are ticketed separately.

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
