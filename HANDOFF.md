# HANDOFF — CommodoreSQL

State: 2026-09-04. Backlog: GitHub Issues / Project 2.

## Repository state

- Branch: **`cmm-spring-2026`**
- PR: [#62](https://github.com/christopherseaman/commodoreSQL/pull/62), open/non-draft.
- The live database remains at the pre-#80 baseline; current branch SQL is newer.
- Inputs and `duckdb/commodore.duckdb` end at Fall 2025 (`2025-4`).
- Spring 2026 and pending lookups remain absent.

## Current implementation

- `material_costs`: canonical Use items LEFT-enriched by exact section × ISBN pricing.
- `section_enrollment`: complete section population and assigned enrollment.
- `sample10pct_materials`: direct stable section-hash sample of `material_costs`.
- `master_section`: owns section costs; no separate `section_cost` relation.
- `current_mailing`: Master contacts in the latest 12 catalog terms, history-enriched, minus opt-outs.

[Flow](CMM-DATA-FLOW.md) · [ETL rules](CMM-ETL.md) · [Dictionary](DATA-DICTIONARY.md)

## Live pre-change baseline

The last full rebuild predates #80/#81/#83/#84. Its raw → canonical → release
reconciliation passed and remains the comparison baseline, not proof of the staged SQL:

- `comprehensive_data`: **102,885,609** enriched source rows
- `course_materials`: **96,663,781** canonical groups/audit rows
- `material_costs`: **12,806,060** canonical Use items
- `master_section`: **6,983,049** material-bearing sections
- Fall 2025: **2,754,111** Material Costs, **1,509,634** Master Section,
  **2,216** Master Institution, and **335,157** Master ISBN rows
- 10% material sample definition: **1,282,423** items, **698,578** material-bearing sections,
  no NULL/duplicate keys, and exact key parity with sampled `course_materials_use`
- Raw conservation, release/key-set, price-cell, mailing, and partition checks passed in that rebuild.

Bounded read-only checks of the staged expressions against that snapshot found:

- Catalog and prior Master produce the same 12-period set. Each yields **1,411,582**
  Master contacts before opt-outs and **1,374,828** Working contacts after opt-outs.
- Direct `sample10pct_materials` hashing reproduces **1,282,423** items and **698,578**
  material-bearing sections with zero key difference from the retired helper join.
- Direct `material_costs` cost aggregation matches all ten existing section cost fields for
  **6,983,049** sections; release reconciliation reports zero differences in every term.
- The direct `master_course` rollup preserves **3,444,030** keys. Decimal-equivalent
  averages differ only by floating aggregation order (maximum absolute difference
  **1.14e-12**); MIN/MAX values are unchanged.

## Next release

1. Human review/merge PR #62 and Review → Done transition.
2. Obtain pending inputs; validate schemas/terms; update `scripts/dot.env`.
3. Stop Metabase, rebuild with bounded resources, validate, restart.
4. Regenerate exports; verify keys/counts before delivery.

**Do not release `output/`: its 2026-08-27 artifacts predate the validated rebuild.**

## Open work

### Flow changes

- [#80](https://github.com/christopherseaman/commodoreSQL/issues/80) — implementation staged; full rebuild/reconciliation pending
- [#81](https://github.com/christopherseaman/commodoreSQL/issues/81) — direct Material Costs hash sample staged; rebuild pending
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
scripts/export_course_materials.sh 20260901 2025-4
```

Stop Metabase before database writes; restart afterward:

```bash
docker stop metabase
MEM_LIMIT=16GB NUM_THREADS=1 scripts/run_sql.sh
docker start metabase
```

Metabase preview: `python3 metabase/sync.py --dry-run`.
