# HANDOFF — CommodoreSQL

State: 2026-09-08. Branch: `cmm-spring-2026`. PR #62 remains open.

## Current state

- Full database rebuild completed; counts and reconciliation evidence are in RERUN.md.
- Both grains remain: `comprehensive_data` preserves enriched source rows;
  `course_material` groups term × section × ISBN, including NULL-ISBN audit groups.
  #86 is canceled. Do not restart consolidation.
- Renamed relations are live. All 74 tracked Metabase queries match the repository and
  bind against DuckDB; 26 changed cards were published and four live requests passed.
- Inputs end at Fall 2025. Materials and mailing share the newest 12 catalog terms.
- No external file release was made. `output/` mixes current and older artifacts;
  select the intended files explicitly.

## Documentation

- CMM-DATA-FLOW.md owns flow, logic, filters, and exports.
- DATA-DICTIONARY.md owns schema presentation. Generated TSVs cover 25 implemented-flow
  relations / 1,201 columns, excluding DQ/off-flow relations. Notion has one inline fields
  database, an all-fields view, 25 table views, and collapsed global/per-table downloads.
  All 1,201 stored records and 26 downloads were verified; repeated field/download applies
  made zero remote writes. Remote-edit protection and interrupted-run recovery are tested.
- README.md owns runner commands and execution order.
- SCHEMA.md and CMM-ETL.md are repo-only pointers; duplicate Notion pages are in recoverable trash.
- Notion prose publication uses five explicit manifest pages: flow, reports, and three
  detail pages under CMM Data Flow. All five were published and readback verified.
  Dedicated dictionary publishers use `scripts/notion_dictionary.json`; preserve ignored
  `.notion/` state, including the prose baselines in `prose-state.json`. Prose sync rejects
  remote edits, skips unchanged pages, and recovers acknowledged writes after failed readback.
  The old dictionary container and 33 static pages are in recoverable trash,
  including the obsolete `section_book_status` page. The home contains Downloads, then the database.
- Supplies input is CMM-owned title rules (`supply_keywords.tsv`); the derived
  `supply_isbn_classification` assigns categories to catalog ISBNs.

## Tickets and next step

#80, #81, #83, #84, #85, #88, #90 and #91 are in Review with implementation/verification evidence;
historical rebuild-hold notes are superseded. Next: review/merge PR #62, then pending inputs
and definitions. #87 is On Deck for final Master
Course/Institution definitions; current provisional rollups and URL lineage are implemented.

Known inputs/decisions stay in their existing tickets:
#21 pricing identity; #23 external pricing; #26 owned-cost reporting;
#51 Spring 2026; #52 discipline; #56 BVA history; #57 campus IA;
#60 institution list/samples; #72 bookstore brand; #76 snapshot retention.
These do not require recreating placeholder database schemas.

## Validation

RERUN.md records the completed full-data checks and corrected sample counts.
The 10% sample is 1,937,043 materials / 1,050,536 sections; the separate
`sample_section_us_intro_fall2025` has 773,613 rows.
Shared-window expansion intentionally changes old fixed-2024+ totals.
The two post-run SQL configuration/summary fixes are row-neutral and fixture-tested.
Adversarial follow-up: 107 tests pass, including actual SQL dictionary fixtures, real-runner
missing/wrong-type output failures, flow/SQL agreement, and sync safety;
standalone cleanup/mailing checks and dictionary/report generation checks pass.
All 15 canonical output names/types also match the live database. No extended rebuild or
new overall-count scan was performed. The September 5 full-data evidence remains the baseline.

## Commands

```bash
duckdb -bail -readonly duckdb/commodore.duckdb
python3 scripts/generate_data_dictionary.py --check
NOTION_KEYRING=0 python3 scripts/sync_notion_docs.py --manifest scripts/notion_sync_docs.txt
NOTION_KEYRING=0 python3 scripts/sync_notion_docs.py --apply --manifest scripts/notion_sync_docs.txt
NOTION_KEYRING=0 python3 scripts/sync_notion_dictionary.py
NOTION_KEYRING=0 python3 scripts/sync_notion_dictionary_downloads.py
```

Full-run and export commands are in README.md. Stop Metabase before database writes and
restart it afterward. Delegate bounded tasks with `fork_turns: "none"`; no descendants.
