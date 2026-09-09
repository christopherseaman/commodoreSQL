# HANDOFF — CommodoreSQL

State: 2026-09-08. Branch: `cmm-spring-2026`. PR #62 remains open.
Last live database/Notion verification: `45a8cd5` (before the staged price change).

## Active batch — #26 price contract

Staged implementation: ten `required_` / `all_` price-summary columns per section
and course. Every legacy price `avg` is the midrange of that grain's own min/max.
#26 owns the decision and validation checklist; #87 retains other master-definition decisions.

SQL, reports, and generated schema/docs are staged together. The live database,
Metabase, and Notion dictionary still use the previous contract. Do not publish renamed
report queries against that database. No extended rebuild or new data release is authorized.
Coordinate the database, report metadata, and Notion field-key migration before deployment.

Deployment remaining under #26:

1. With an approved execution window, rebuild section/course outputs using
   `4_merged_records.sql`; check keys, price bounds/midranges, and release reconciliations.
2. Refresh Metabase schema metadata, then publish changed reports and verify live results.
3. Migrate the Notion dictionary's 33 old price-field keys to 30 new definitions across
   section/course/section-sample; preserve recognized row IDs and remote edits. The normal
   publisher deliberately refuses removed keys. Then publish the field/download/prose updates.

## Current state

- Full database rebuild completed September 5; September 8 changes are row-neutral.
  Historical [run evidence](https://github.com/christopherseaman/commodoreSQL/blob/45a8cd52a7f83ec7c5ca537826e0027f95dee590/RERUN.md)
  remains in Git; no active run diary is needed.
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
  relations / 1,198 staged columns, excluding DQ/off-flow relations; live Notion still has
  the previous 1,201 fields. Notion has one inline fields
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

24 non-Done project cards: 8 Review, 5 On Deck, 10 Todo, 1 In Progress; no draft-only cards.

| Status | Tickets / remaining work |
|---|---|
| Review | #80, #81, #83, #84, #85, #88, #90, #91 — implemented and verified; human review/merge of PR #62 |
| In Progress | #26 approved price contract staged; live migration/publication pending |
| On Deck | #21 pricing identity design/implementation; #87 remaining non-price master definitions |
| On Deck, missing inputs | #51 Spring 2026; #52 discipline lookup; #60 25-institution list |
| Todo, missing inputs | #23 external pricing; #56 BVA history; #57 campus IA; #72 bookstore brand |
| Todo, decisions | #76 snapshot retention |
| Older Todo backlog | #19 DQ logging; #30 Metabase organization; #43 cost/OER modeling; #47 drill-down tools; #48 program-level ideas |

Next: review staged #26 changes and schedule coordinated deployment; then #21 work or #87 decisions.
Provisional masters and institution URL lineage already exist. Do not reopen completed
rebuild/migration work based on superseded ticket notes or the stale September 5 project overview.
Canonical-stage runtime/spill optimization has no dedicated ticket; it is a non-blocking
observation, not active work. Known DuckDB resource-limit behavior is not a release blocker.

## Validation

September 5 baseline: 102,885,609 source/enriched rows; 96,663,781 canonical materials;
19,387,814 `master_material` rows; 10,514,319 `master_section` rows.
Release/key/material reconciliations: 241 passed. Samples: 254 passed, zero failed,
34 not applicable. See the historical run evidence for full counts and DQ findings.
The 10% sample is 1,937,043 materials / 1,050,536 sections; the separate
`sample_section_us_intro_fall2025` has 773,613 rows.
Shared-window expansion intentionally changes old fixed-2024+ totals.
The two post-run SQL configuration/summary fixes are row-neutral and fixture-tested.
Staged #26 validation: 108 pipeline tests plus three actual-report tests pass. Cases cover
all ten price columns at both grains, optional-only/all-missing/partial/zero/rental prices,
and unequal section ranges. All 74 report queries bind against an isolated schema; the five
changed price queries also pass numerical checks. Dictionary names/types/order match the SQL
fixture for section (67 columns), course (50), and section sample (67). Independent review passed.
Standalone cleanup/mailing and both generator checks pass. No extended rebuild or new
overall-count scan was performed; September 5 full-data evidence covers the previous contract.

## Handoff rules

- Read this file, project `AGENTS.md`, and user `~/.codex/AGENTS.md` first; fetch current
  ticket/project statuses before starting. Project status, not issue-open state, tracks completion.
- Do not restart #86 consolidation, broaden the pricing join, invent missing-source schemas,
  or run another extended rebuild without a new request.
- Preserve `.notion/` state and `output/`. Do not publish repo-only handoff/run history to Notion.
- Update this file after each completed work batch: verified commit, remaining work,
  validation limits, and next action. Keep detailed evidence in tickets or Git history.

## Commands

```bash
duckdb -bail -readonly duckdb/commodore.duckdb
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 -m unittest metabase.test_price_summaries -v
python3 scripts/generate_data_dictionary.py --check
NOTION_KEYRING=0 python3 scripts/sync_notion_docs.py --manifest scripts/notion_sync_docs.txt
NOTION_KEYRING=0 python3 scripts/sync_notion_docs.py --apply --manifest scripts/notion_sync_docs.txt
NOTION_KEYRING=0 python3 scripts/sync_notion_dictionary.py
NOTION_KEYRING=0 python3 scripts/sync_notion_dictionary_downloads.py
```

Full-run and export commands are in README.md. Stop Metabase before database writes and
restart it afterward. Delegate bounded tasks with `fork_turns: "none"`; no descendants.
