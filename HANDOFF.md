# HANDOFF — CommodoreSQL

Pickup state as of **2026-09-01**; GitHub Issues and Project 2 are the backlog of record.

## Repository state

- Branch: **`cmm-spring-2026`**
- PR: **[#62](https://github.com/christopherseaman/commodoreSQL/pull/62)** is open, non-draft, and mergeable.
- Executable SQL and the database baseline were audited at **`62479bf`**; later commits on this branch may be documentation-only.
- Local inputs and `duckdb/commodore.duckdb` end at **Fall 2025 (`2025-4`)**.
- Current-input implementation is complete; no Spring 2026 data or pending lookup has landed.

## Current implementation

The repository now has one canonical course-material flow:

```text
comprehensive_data
  -> course_materials + section_enrollment
  -> material_costs <- pricing_wide
  -> section_cost
  -> master_section / master_institution / master_isbn
```

`course_materials` is the canonical catalog item spine; `material_costs` is its Use
population with LEFT exact section×ISBN pricing enrichment. Pricing remains source-owned;
`section_enrollment` owns the complete section population and assigned enrollment.

Mailing routes from normalized inputs to `master_mailing`; `current_mailing` applies history,
the 12-period window, and opt-outs. See [`MAILING-FLOW.md`](MAILING-FLOW.md).

Detailed contracts: [`COURSE-MATERIAL-POPULATIONS.md`](COURSE-MATERIAL-POPULATIONS.md),
[`PRICING-CATALOG-MATCHING.md`](PRICING-CATALOG-MATCHING.md), [`SCHEMA.md`](SCHEMA.md),
[`CMM-ETL.md`](CMM-ETL.md), and [`DATA-DICTIONARY.md`](DATA-DICTIONARY.md).

## Validation baseline

The current database passed the implemented raw→canonical→release reconciliation:

- `comprehensive_data`: **102,885,609** enriched source rows
- `course_materials`: **96,663,781** canonical groups/audit rows
- `material_costs`: **12,806,060** canonical Use items
- `master_section`: **6,983,049** material-bearing sections
- Fall 2025: **2,754,111** Material Costs, **1,509,634** Master Section,
  **2,216** Master Institution, and **335,157** Master ISBN rows
- Raw conservation, release/key-set, price-cell, mailing, and partition checks passed.

These values validate only the current inputs through `2025-4`.

## Immediate merge and release actions

1. Review and merge PR #62; the human owns the project’s Review → Done transition.
2. Obtain and inventory the external inputs below before a Spring 2026 rebuild.
3. Update `CSV_DATE` and paths in `scripts/dot.env`; validate source schemas and periods.
4. Stop Metabase, run with bounded memory/temp space, validate, then restart it.
5. Regenerate release files and verify their keys/counts before delivery.

**Do not release the ignored `output/` artifacts.** They date from 2026-08-27, predate
the current canonical rebuild, and are not validation evidence. Regenerate them.

## Open work

### Actionable now: #21

[#21](https://github.com/christopherseaman/commodoreSQL/issues/21) must define a source-aware
catalog/pricing section crosswalk while preserving `Section`, `Section Code`, and `CRN`.
Promote only unambiguous matches; retain/count collisions and never globally strip padding.
Then update match evidence, required inference, DQ, impacts, and documentation. Current
behavior remains exact section×ISBN; see [`PRICING-CATALOG-MATCHING.md`](PRICING-CATALOG-MATCHING.md).

### External blockers

- [#51](https://github.com/christopherseaman/commodoreSQL/issues/51) — Spring 2026 source drops
- [#52](https://github.com/christopherseaman/commodoreSQL/issues/52) — `cmm_discipline`
- [#56](https://github.com/christopherseaman/commodoreSQL/issues/56) — updated BVA mailing history
- [#57](https://github.com/christopherseaman/commodoreSQL/issues/57) — campus IA (`cmm_ia`)
- [#60](https://github.com/christopherseaman/commodoreSQL/issues/60) — 25-institution fixture/extracts
- [#72](https://github.com/christopherseaman/commodoreSQL/issues/72) — bookstore-brand lookup
- [#75](https://github.com/christopherseaman/commodoreSQL/issues/75) — authoritative supplies lookup
- [#76](https://github.com/christopherseaman/commodoreSQL/issues/76) — snapshot-retention decision

### Held decision: #26

[#26](https://github.com/christopherseaman/commodoreSQL/issues/26) requires a PI decision:
all required materials or the current buy-priced subset, plus approved labels. Do not change it.

## Essential commands

Read-only query with bounded resources:

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

Metabase holds the database write lock. Stop it before DB writes and restart it
afterward:

```bash
docker stop metabase
MEM_LIMIT=16GB NUM_THREADS=1 scripts/run_sql.sh
docker start metabase
```

Preview Metabase config with `python3 metabase/sync.py --dry-run`. For detail, use
`SCHEMA.md`, `CMM-ETL.md`, `DATA-DICTIONARY.md`, and `DASHBOARDS-REPORTS.md`.
