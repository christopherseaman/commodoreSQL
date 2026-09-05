# HANDOFF — CommodoreSQL

State: 2026-09-04. Backlog: GitHub Issues / Project 2.

## Repository state

- Branch: **`cmm-spring-2026`**
- PR: [#62](https://github.com/christopherseaman/commodoreSQL/pull/62), open/non-draft.
- SQL/database audited at `62479bf`; later documentation edits do not validate new data.
- Inputs and `duckdb/commodore.duckdb` end at Fall 2025 (`2025-4`).
- The validated database remains at the pre-#80 baseline; Spring 2026 and pending lookups remain absent.

## Current implementation

- `material_costs`: canonical Use items LEFT-enriched by exact section × ISBN pricing.
- `section_enrollment`: complete section population and assigned enrollment.
- `sample10pct_materials`: stable section-cluster sample of `material_costs`.
- `current_mailing`: latest contacts, 12-term window, history, minus opt-outs.

[Flow](CMM-DATA-FLOW.md) · [ETL rules](CMM-ETL.md) · [Dictionary](DATA-DICTIONARY.md)

## Validation baseline

Raw → canonical → release reconciliation passed:

- `comprehensive_data`: **102,885,609** enriched source rows
- `course_materials`: **96,663,781** canonical groups/audit rows
- `material_costs`: **12,806,060** canonical Use items
- `master_section`: **6,983,049** material-bearing sections
- Fall 2025: **2,754,111** Material Costs, **1,509,634** Master Section,
  **2,216** Master Institution, and **335,157** Master ISBN rows
- 10% material sample definition: **1,282,423** items, **698,578** material-bearing sections,
  no NULL/duplicate keys, and exact key parity with sampled `course_materials_use`
- Raw conservation, release/key-set, price-cell, mailing, and partition checks passed.

## Next release

1. Human review/merge PR #62 and Review → Done transition.
2. Obtain pending inputs; validate schemas/terms; update `scripts/dot.env`.
3. Stop Metabase, rebuild with bounded resources, validate, restart.
4. Regenerate exports; verify keys/counts before delivery.

**Do not release `output/`: its 2026-08-27 artifacts predate the validated rebuild.**

## Open work

### Flow changes

- [#80](https://github.com/christopherseaman/commodoreSQL/issues/80) — implementation staged; full rebuild/reconciliation pending
- [#81](https://github.com/christopherseaman/commodoreSQL/issues/81) — in Review; 1,282,423-row sample reconciled
- [#24](https://github.com/christopherseaman/commodoreSQL/issues/24) — rationalize course summary views

### Reliability

- [#82](https://github.com/christopherseaman/commodoreSQL/issues/82) — make DuckDB runners fail on the first SQL error

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
duckdb -readonly duckdb/commodore.duckdb <<'SQL'
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
