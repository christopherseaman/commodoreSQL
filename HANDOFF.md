# HANDOFF — CommodoreSQL

State: 2026-09-09. Branch: `cmm-spring-2026`. PR #62 remains open.
Live database rebuilt from `b4bd234`; independent supervisor QA accepted.

## Meeting transcript reconciled

`comms/26-09-09.md` combines the full transcript, quick notes, follow-up email, and current
task status. Original VTT, 919-cue timestamped text, and original quick notes are retained
in `comms/media/`. The transcript is received, not pending.

- #95 is **not just awaiting rebuild**: 01:02:41–01:06:45 explicitly rejects rollup-average
  fields, including legacy midranges. Earlier retention guidance is superseded as a meeting
  requirement; existing SQL still retains those fields and needs coordinated consumer/doc work.
- #102 now tracks required/all ISBN institution/section/enrollment measures, separate from prices.
- #103 tracks human-reviewable institution-ID exceptions for Jeff; no automatic crosswalk.
- #94 must distinguish within-section × ISBN variation from Jeff's full-Fall2025 ISBN request;
  reuse existing #45/#37 reports and extend missing field/section-frequency coverage.
- #101 meaning is clarified: commercial textbook with a good OER alternative; file and
  operational evidence remain pending. #99 now records student reach/gateway prioritization.
- #72 records no public brand findings; confidential output scope still needs approval.
- #21 records Jeff's favored institution/term/ISBN fallback direction; no fixed 97% rule or
  conflict/timepoint policy was defined, and no fallback was activated.

This was notes/task reconciliation only: no ETL/schema/source change or rebuild.
Published the consolidated notes and 17-task table to the existing September 9 Notion
meeting page; native transcript/workbook attachments, email, title and properties preserved.
Independent content review corrected the missing point-in-time/110% sensitivity proposal;
that proposal is not an approved multiplier. New #102/#103 are in the project as Todo.
Publication boundary: the repository is public. Full VTT/readable transcript captures include
personal conversation and are held local/in Notion pending explicit public-publication approval;
the consolidated project notes and workbook are included in the repository update.

## Latest team batch — #21 / #95 / #96 / #97

#95's eight ISBN bounds and #96's dependency cleanup are staged and independently reviewed.
They await an authorized rebuild/full-data QA; #95 additionally needs the newly recovered
no-average requirement above. No live database write or extended rebuild ran in this batch.

- #95: eight required/all ISBN price bounds sum canonical material occurrences by term × ISBN;
  existing section/course midranges and ISBN offer counts remain unchanged.
- #96: removed both contact-history/opt-out joins and five fields from the materials branch.
  This fully removes the double dependency, satisfying Christopher's conditional approval.
  `current_mailing` retains both inputs; raw-catalog email selection and filters are unchanged.
- Local regenerated dictionary describes staged SQL: 25 golden-path relations / 1,171 fields;
  32 total relations / 1,201 fields including repo-only DQ. Live Notion still has 1,198 fields.
  Do not publish staged field records/downloads until the rebuilt schema passes verification.
- #97: standard nested outlines, actual report links, provisional export styling, and 100-ID
  pending sample labels are implemented and published; ticket is in Review. Human visual
  inspection of Notion's rendered Mermaid remains pending (source and blocks verified).
- #21: fresh read-only two-direction accounting preserves production exact-match semantics;
  institution/term/ISBN evidence is labeled candidate, not proof of an encoding cause.
  Cards 181 (13 accounting rows) and 182 (20 examples) were published and executed against
  the live database; results agree with standalone diagnostics. Ticket returns to On Deck
  for cause/crosswalk and matching-policy decisions. No fallback was activated.

Validation: 128 script tests, 5 Metabase tests, both generator checks, and independent review
pass. Four changed prose pages were published/readback verified; all six are unchanged on
repeat apply. Native readback verified 25 flow table headings and no embedded linebreaks
across 279 prose/list blocks. New report definitions are `metabase/questions/73_*.sql` and
`74_*.sql`; the inventory now has 72 questions, 4 models, and 14 dashboards.

Follow-up input receipt: `comms/media/CMM_100Inst_Regions_Compacts.xlsx` and both sheet TSVs
are captured; email, hash, and checks are in `comms/26-09-09.md`. All 100 unique UNITIDs
match current IPEDS. The 52-code lookup has overlapping ND/SD compact memberships,
division-label differences, and missing territory mappings; #98 records the decisions.
#60/#98 now have their inputs but no imports/models have been implemented for them.
IPEDS 2025 replacement (#51), revised opt-out (#56), UNITID IA (#57), ISBN OER-ready
(#101) and discipline (#52) remain pending. The revised opt-out is distinct
from the separately pending mailing-history update. Notion already contains the email;
no duplicate communication page was posted. Data Flow receipt/pending notes were synced
and readback verified; five diagram tests pass. No pipeline or schema changed for receipt.
Deployment remains pending; Git history records the accumulated implementation and capture work.

## Incoming — September 9 Jeff discussion

Notes and request-to-ticket mapping: `comms/26-09-09.md`; receipt updates above supersede
the initial pending-input list. Christopher reaffirmed section × ISBN grain; no new material key or #86 consolidation.
#94 covers field-variation EDA; new #95 pricing rollups, #96 dependency cleanup, #97 standard
outline/navigation fixes, #98 region/compact lookup, #99 manual-price-collection triage,
and #100 optional Dropbox delivery are tracked. Current implementation status is above.
#60 now specifies 100 institutions (pending diagram names updated; input received); #52 discipline
and #57 high-priority campus IA are On Deck; #72 brand remains lower-priority Todo.
#21 now explicitly covers matching causes/populations and candidate gains; #23 depends on
#99's collection worklist before ingestion. #26/#92 retain Review for completed earlier work.
Live dictionary/database fields before deployment: master_material 136, master_section 67,
master_isbn 44. Staged counterparts: 131, 67, and 52. Section retains ten monetary summaries;
the eight new ISBN bounds are not a display-only change. Existing midranges are still present;
their removal from rollups is now required under the transcript clarification above.

## Completed — #92 dictionary clarity

The generator, TSVs, and Notion now separate upstream table, derivation, and illustrative
sample values. Corrected formulas, lookup/filtered sample labels, category NULL wording,
and Data Flow representative selection/release rollups. No ETL change or rebuild.
115 script tests and generation checks pass; independent review findings were corrected.
All 1,198 samples passed type conversion. Notion verified 1,198 field records, 26 downloads,
and six prose pages; row/property/file/view IDs were retained. Repeat field/download
applies made zero writes, and all 26 view configurations verified unchanged on repeat.
One transient PATCH failure was safely resumed after a conflict-free read-only preview.
Logs: `output/logs/dictionary-contract-20260909/`. #92 is back in Review.

Formatting follow-up: removed Pricing Matching's opening paragraph. Prose publication
now joins source-width paragraph/list continuations; local Markdown and Notion cell-wrap
settings stay unchanged. Published five changed pages; all six verify unchanged on repeat.
Live inspection found zero embedded line breaks across 97 prose/list blocks. Code/diagrams,
tables, headings, and native child-page links are preserved; 119 tests and independent review pass.

Heading follow-up: Notion publication promotes section headings one level, preserving local
Markdown hierarchy. Data Flow now groups table logic by diagram area, with one subsection
per relation: `Logic` → `Materials` → `comprehensive_data`, for example. All six pages published;
live heading types and all 25 implemented table headings verified. Repeat apply made zero writes;
106 prose/list blocks contain no embedded line breaks. All 123 tests, generation checks, and
independent review pass. No SQL/diagram changes. The two older detail pages remain pending
the user's archival decision.

Data Flow formatting: table/source logic now uses one bullet per point. Pending inputs
use individual source subsections and bullets instead of a summary table.

Population-logic follow-up: rewrote Data Flow bullets against executable SQL to name
upstream columns, join types/keys, row filters, and output formulas. Clarified labeling
versus filtering, enrollment assignment, canonical aggregates, and release counts/prices.
Independent review corrections applied; 35 focused flow/publisher tests pass. Notion
readback verified and repeat apply made zero writes. No SQL, diagram, schema, or data change.

## Latest investigation — #21 pricing matching

Local write-up: `PRICING-CATALOG-MATCHING.md`; reproducible read-only SQL in
`scripts/diagnostics/pricing_match_coverage.sql`, `pricing_offer_consistency.sql`, and
`pricing_population_accounting.sql`. Latest evidence: `output/logs/issue21-populations-20260909/`.
Fall 2025 retained pricing: 5,459,527 observations / 2,510,652 keys; 1,854,709 exact catalog
keys (1,837,586 Use + 17,123 NoUse), leaving 655,943 unmatched pricing keys.
Canonical Use: 2,754,111 keys from 2,757,330 source rows; 916,525 lack exact pricing.
Of those, 560,758 have valid-key institution/term/ISBN candidates; 355,767 lack that source.
The broader 570,416 below includes 9,658 keys supported only by invalid pricing composites.
Fall 2025: 570,416 possible institution/term/ISBN recoveries; 512,589 have identical
wide price payloads and one retained-source bookstore. Same-timestamp/store/offer
groups agree 99.68%, but 553 groups disagree; a term is not a common snapshot.
The write-up recommends testing exact-first, institution-scoped fallback, not implementing
it yet. Time-window/staleness, product identity, single-section evidence, and conflicting
offers remain decisions. #21 stays On Deck; investigation is complete, implementation is not.
Diagnostics executed against the read-only live database. Independent review corrected
key-grain, exact-match precedence, candidate labeling, and a prose denominator error.
No fresh full-pipeline QA was performed. Data Flow and Pricing Matching were published
and readback verified; small remote wording/spacing edits were preserved.

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
- Notion prose publication uses six explicit manifest pages: Data Flow, Reports, two
  detail pages under Data Flow, Pricing Matching in Overview, and Top-125 in Resources /
  Snippets. This hierarchy update is published and readback verified; six-page repeat verification passed.
  Dedicated dictionary publishers use `scripts/notion_dictionary.json`; preserve ignored
  `.notion/` state, including the prose baselines in `prose-state.json`. Prose sync rejects
  remote edits, skips unchanged pages, and recovers acknowledged writes after failed readback.
  The old dictionary container and 33 static pages are in recoverable trash,
  including the obsolete `section_book_status` page. The home contains Downloads, then the database.
- Supplies input is CMM-owned title rules (`supply_keywords.tsv`); the derived
  `supply_isbn_classification` assigns categories to catalog ISBNs.

## Tickets and next step

36 non-Done project cards: 12 Review, 7 On Deck, 2 In Progress, 15 Todo; no draft-only items.

| Status | Tickets / remaining work |
|---|---|
| Review | #26, #80, #81, #83, #84, #85, #88, #90, #91, #92, #93, #97 — human review/merge of PR #62; #97 rendered Notion appearance check |
| On Deck | #21 cause/crosswalk and matching-policy decisions; #87 remaining non-price master definitions |
| On Deck, inputs received | #60 100-institution samples; #98 region/compact integration (overlap and fallback rules) |
| In Progress | #95 pricing bounds staged, rollup-average removal still needed; #96 dependency cleanup staged — rebuild/full-data QA and live dictionary publication pending |
| On Deck, missing inputs | #51 Spring 2026 / IPEDS 2025; #52 discipline lookup; #57 campus IA (high priority) |
| Todo, missing inputs | #23 external pricing (also awaits #99 collection); #56 BVA history / revised opt-out; #72 bookstore brand (lower priority); #101 ISBN OER-ready |
| Todo, decisions | #76 snapshot retention |
| Todo, analysis | #94 within-section × ISBN field variation; #99 external-price collection worklist |
| Todo, transcript follow-ups | #102 required/all ISBN adoption counts; #103 institution-ID review queue |
| Todo, optional delivery | #100 Dropbox assessment; no upload authorized |
| Older Todo backlog | #19 DQ logging; #30 Metabase organization; #43 cost/OER modeling; #47 drill-down tools; #48 program-level ideas |

Before deployment, finish #95's recovered no-average rollup requirement and its consumers.
Next deployment: run the pipeline when authorized; compare source/canonical/mailing counts
and price reconciliation, verify removed contact fields and eight ISBN bounds, then publish
Notion fields/downloads and refresh Metabase metadata. Do not use the prior rebuild as evidence
for staged #95/#96. #94 field-variation EDA and #99 price-collection triage remain Todo.
Implement received #60/#98 inputs after resolving the lookup semantics; acquire pending
inputs for #51/#52/#56/#57/#101. This attachment receipt did not authorize a rebuild.
Human review/merge of PR #62 and #87 non-price decisions remain pending.
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
