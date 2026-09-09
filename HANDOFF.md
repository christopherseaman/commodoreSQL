# HANDOFF — CommodoreSQL

State: 2026-09-08. Branch: `cmm-spring-2026`. PR #62 remains open.
Live database rebuilt from `b4bd234`; independent supervisor QA accepted.

## Completed batch — #92 / #93 documentation audit

Corrected filtered dictionary value/NULL contracts at the generator, qualified provisional
course enrollment, and replaced the stale Top-125 page with maintained `TOP125-REPORT.md`.
Its previous content is preserved in `comms/top125-report-before-canonical-update.md`.
Mixed-source flags remain possible in canonical Use groups; ISBN identifiers are not
guaranteed 13 digits, and the section sample's state filter does not trim whitespace.

DQ critical checks exclude seven legitimate NULL-bound pricing groups, which remain
visible in coverage. Import summaries and source-stage labels now describe actual SQL.
Metabase publication changed 15 cards (only two queries) and two dashboard descriptions;
74 SQL/filter definitions and 14 layouts/mappings verify. Cards 56, 57, and 68 were executed;
all six critical metrics are zero. Evidence: `output/logs/docs-audit-metabase-20260909T054903Z-dq/`.
Notion publication updated 28 fields, seven TSV downloads, and four prose pages;
all 1,198 fields, 26 downloads, and six prose pages verify. Repeat applies made zero writes.
109 script tests and five Metabase tests pass; both generators are current; independent review passed.
No ETL SQL, data, or pipeline configuration changed; no rebuild was run. #92 / #93 are in Review.

## Completed batch — #26 price contract

Implemented: ten `required_` / `all_` price-summary columns per section
and course. Every legacy price `avg` is the midrange of that grain's own min/max.
#26 owns the decision and validation checklist; #87 retains other master-definition decisions.

The full pipeline finished September 8 at 20:43 PDT; Luna QA finished at 20:47.
The supervisor independently accepted schema, counts, reconciliations, and price checks.
Run details and publication evidence belong in `RUN-2026-09-08.md`.
Metabase and Notion updates are published and verified. #26 is in Review for PR #62;
no rebuild or publication step remains. No external data-file release was made.

## Current state

- Full database rebuild completed September 8; counts match September 5 exactly.
  Historical [run evidence](https://github.com/christopherseaman/commodoreSQL/blob/45a8cd52a7f83ec7c5ca537826e0027f95dee590/RERUN.md)
  remains in Git; the new run's evidence belongs in `RUN-2026-09-08.md`.
- Both grains remain: `comprehensive_data` preserves enriched source rows;
  `course_material` groups term × section × ISBN, including NULL-ISBN audit groups.
  #86 is canceled. Do not restart consolidation.
- Renamed relations and the new price schema are live. All 74 tracked Metabase SQL/filter
  definitions match the repository; all 14 dashboards preserve mappings and layouts.
  Five changed reports were executed against DuckDB results. Card 75 is API-limited to
  2,000 of 2,232 rows; all returned rows match. The other four match completely.
- Inputs end at Fall 2025. Materials and mailing share the newest 12 catalog terms.
- No external file release was made. `output/` mixes current and older artifacts;
  select the intended files explicitly.

## Documentation

- CMM-DATA-FLOW.md owns flow, logic, filters, and exports.
- DATA-DICTIONARY.md owns schema presentation. Generated TSVs cover 25 implemented-flow
  relations / 1,198 columns, excluding DQ/off-flow relations. All 1,198 live Notion field
  records and 26 downloadable TSVs are verified. Notion has one inline fields database,
  an all-fields view, 25 table views, and collapsed global/per-table downloads.
  The 30 renamed field rows retain their IDs; three removed buy-average rows are in
  recoverable trash. Remote-edit protection and interrupted-run recovery are tested.
  Repeated field, download, and prose applies made zero remote writes.
- README.md owns runner commands and execution order.
- SCHEMA.md and CMM-ETL.md are repo-only pointers; duplicate Notion pages are in recoverable trash.
- Notion prose publication uses six explicit manifest pages: flow, reports, three
  detail pages under CMM Data Flow, and Top-125 in Resources / Snippets. All six were readback verified.
  Dedicated dictionary publishers use `scripts/notion_dictionary.json`; preserve ignored
  `.notion/` state, including the prose baselines in `prose-state.json`. Prose sync rejects
  remote edits, skips unchanged pages, and recovers acknowledged writes after failed readback.
  The old dictionary container and 33 static pages are in recoverable trash,
  including the obsolete `section_book_status` page. The home contains Downloads, then the database.
- Supplies input is CMM-owned title rules (`supply_keywords.tsv`); the derived
  `supply_isbn_classification` assigns categories to catalog ISBNs.

## Tickets and next step

26 non-Done project cards: 11 Review, 5 On Deck, 10 Todo; none In Progress or draft-only.

| Status | Tickets / remaining work |
|---|---|
| Review | #26, #80, #81, #83, #84, #85, #88, #90, #91, #92, #93 — implemented and verified; human review/merge of PR #62 |
| On Deck | #21 pricing identity design/implementation; #87 remaining non-price master definitions |
| On Deck, missing inputs | #51 Spring 2026; #52 discipline lookup; #60 25-institution list |
| Todo, missing inputs | #23 external pricing; #56 BVA history; #57 campus IA; #72 bookstore brand |
| Todo, decisions | #76 snapshot retention |
| Older Todo backlog | #19 DQ logging; #30 Metabase organization; #43 cost/OER modeling; #47 drill-down tools; #48 program-level ideas |

Next: human review/merge of PR #62; then #21 work or #87 non-price decisions.
Provisional masters and institution URL lineage already exist. Do not reopen completed
rebuild/migration work based on superseded ticket notes or the stale September 5 project overview.
Canonical-stage runtime/spill optimization has no dedicated ticket; it is a non-blocking
observation, not active work. Known DuckDB resource-limit behavior is not a release blocker.

## Validation

September 8 rebuilt counts: 102,885,609 source/enriched rows; 96,663,781 canonical materials;
19,387,814 `master_material` rows; 10,514,319 `master_section` rows.
Release/key/material reconciliations: 265 passed. Samples: 254 passed, zero failed,
34 not applicable. See `RUN-2026-09-08.md` for full counts and DQ findings.
The 10% sample is 1,937,043 materials / 1,050,536 sections; the separate
`sample_section_us_intro_fall2025` has 773,613 rows.
Shared-window expansion intentionally changes old fixed-2024+ totals.
The two post-run SQL configuration/summary fixes are row-neutral and fixture-tested.
#26 validation: 108 pipeline tests plus three actual-report tests pass. Cases cover
all ten price columns at both grains, optional-only/all-missing/partial/zero/rental prices,
and unequal section ranges. All 74 report queries bind against an isolated schema; the five
changed price queries also pass numerical checks. Dictionary names/types/order match the SQL
fixture for section (67 columns), course (50), and section sample (67). Independent review passed.
Standalone cleanup/mailing and both generator checks pass. Full-data section/course bounds
and midrange checks have zero mismatches. Supervisor independently matched all 1,228 live
column names/types/order and recomputed all ten price fields for 10,559 sections: zero differences.

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
python3 -m unittest discover -s metabase -p 'test_*.py'
python3 scripts/generate_data_dictionary.py --check
python3 scripts/generate_dashboards_reports.py --check
NOTION_KEYRING=0 python3 scripts/sync_notion_docs.py --manifest scripts/notion_sync_docs.txt
NOTION_KEYRING=0 python3 scripts/sync_notion_docs.py --apply --manifest scripts/notion_sync_docs.txt
NOTION_KEYRING=0 python3 scripts/sync_notion_dictionary.py
NOTION_KEYRING=0 python3 scripts/sync_notion_dictionary_downloads.py
```

Full-run and export commands are in README.md. Stop Metabase before database writes and
restart it afterward. Delegate bounded tasks with `fork_turns: "none"`; no descendants.
