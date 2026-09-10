# Original quick notes — September 9

## Pending items

- will be 100 institutions sample, not 25. "coming EoD"
- have discipline can share EoD
- region update inbound with different kinds of region and regional compact membership (need to rename "region" col? since there is no single standard defining regions)
- IA high priority coming next
- brand lower priority (don't get sued!)
- external pricing requires current work to triage which pricing actual humans will pursue to create this dataset

## comprehensive data vs course material

Better explain granularity difference. Each table should start with a bullet stating it's group by (unit of analysis)

- want one row per section x material, not per section x isbn
- same isbn with variability, what is that variabiliity? e.g., formattype (et al.) needs aggregation, when same material via IA or not

## Potpourri

high level summary of price issue: there are pricing rows that do not match to course materials using section_id x ISBN, correct? first, why? related to filter from comprehensive_data → course_material filter? how much fixed by matching within institution (unit_id)?

Why is there an odd straggler bullet under "pending inputs" not associated with any table?

dashboard/report list should link to the dashes/reports!

section enrollment needs to define prioritization logic

some exports aren't highlighted yellow but should be. Nice-to-have push export to dropbox

For pricing aggregations, master_isbn and in general, aggregation on materials should be done on required_\* and all_\*, min/max sums, and min/max with ownership (buy) regardless of format (digital/print) or new/used (or other?). No aggregation of average, using either legacy or standard definition of avg.

Logic in general: organize outline to  unit of analysis (group by), joins, filters (having, where), derivations

Master material doesn't include pricing in data dictionary?!? Sync issue?

Double deps? e.g., panel_email feeds into comprehensive data and current_mailing, which itself is downstream of comprehensive data
