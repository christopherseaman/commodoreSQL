---
notion-id: 381d9fdd-1a1a-81a8-afcc-e187af8f6d11
captured: 2026-09-08
status: historical-before-canonical-report-update
---

# Top-125 report — historical snapshot

Preserved before correcting the active Notion page. Counts, joins, field names, and
illustrative analysis below describe the earlier report, not the current pipeline.

## What was done
Link: [meta.badmath.org](https://meta.badmath.org/question/125-top-100-isbn-cost-extract-fall-2025-institution-course-faculty)
Per-instance data extract to analyze **textbook cost differences across institutions, programs, and courses:**
- **125 most common ISBNs** in Fall 2025 (each appears in **631–19,933** sections).
- **One row per section-adoption instance → 183,324 rows**, combining:
	- **Institution class** — control, iclevel (2yr/4yr), instsize, sector, state, enrollment
	- **Required flag** — `filter_include` (inferred is_required, issue #1); \~75% of instances are required
	- **Course** — title, subject, level, department, section, enrollments
	- **Faculty** — instructor, name, email
	- **Cost** — full buy/rental × new/used × physical/digital grid + min/max + owned ranges
- Source: `comprehensive_data` (institution + course + faculty) **LEFT JOIN** `pricing_wide` (costs) on `(section_id, ISBN13)`.
- **Metabase:** “Top-125 ISBN Cost Extract — Fall 2025” (card 125)  ·  **Ticket:** GitHub #33.
## Decisions
- **“Most common”** = ranked by **distinct sections** in Fall 2025 (`period_sortable = '2025-4'`).
- **Grain** = one row per `(section_id, ISBN13)` adoption instance.
- Costs come from `pricing_wide`, keyed on `section_id` (which embeds `unit_id`) → each institution’s listing carries its own prices, so same-ISBN cross-institution comparison needs no extra joins.
## Caveats
- **\~37% of instances have no matched bookstore price** (NULL cost columns). Filter `price_min IS NOT NULL` / `has_buy` for priced-only analysis, and **check priced-coverage by class before comparing** — uneven coverage can bias unweighted means.
- **Wide within-class spread** (one title ranges \~\$13–\$194 within public 4yr) — prefer medians / distributions over means.
- **Per-instance grain**: a school with N sections of a title contributes N rows; weight when rolling up to institution level.
- \~252 exact within-period source dupes (negligible). Metabase shows the first 2,000 rows; full 183k exportable (CSV/XLSX).
## Sample — same ISBN across institutions
APA *Publication Manual* (ISBN 9781433832161), buy price + range:
<table header-row="true">
<tr>
<td>Institution</td>
<td>State</td>
<td>Control</td>
<td>Lvl</td>
<td>Instructor</td>
<td>New</td>
<td>Used</td>
<td>Min</td>
<td>Max</td>
</tr>
<tr>
<td>Abilene Christian University</td>
<td>TX</td>
<td>Private NFP</td>
<td>4yr</td>
<td>Michael Pounds</td>
<td>\$37.28</td>
<td>\$27.99</td>
<td>\$18.66</td>
<td>\$45.59</td>
</tr>
<tr>
<td>Academy of Art University</td>
<td>CA</td>
<td>Private FP</td>
<td>4yr</td>
<td>—</td>
<td>\$37.32</td>
<td>\$27.99</td>
<td>\$27.99</td>
<td>\$45.59</td>
</tr>
<tr>
<td>Adams State University</td>
<td>CO</td>
<td>Public</td>
<td>4yr</td>
<td>Neil Rigsbee</td>
<td>\$34.95</td>
<td>\$28.95</td>
<td>\$21.95</td>
<td>\$34.95</td>
</tr>
<tr>
<td>Alabama A & M University</td>
<td>AL</td>
<td>Public</td>
<td>4yr</td>
<td>Nathan Hulsey</td>
<td>\$44.99</td>
<td>\$33.75</td>
<td>\$19.80</td>
<td>\$44.99</td>
</tr>
<tr>
<td>Alaska Pacific University</td>
<td>AK</td>
<td>Private NFP</td>
<td>4yr</td>
<td>Nora Miller</td>
<td>\$35.00</td>
<td>\$26.25</td>
<td>\$22.74</td>
<td>\$38.00</td>
</tr>
<tr>
<td>Albertus Magnus College</td>
<td>CT</td>
<td>Private NFP</td>
<td>4yr</td>
<td>James Bulosan</td>
<td>\$37.28</td>
<td>\$27.99</td>
<td>\$18.66</td>
<td>\$45.59</td>
</tr>
</table>
## Illustrative — avg new-print price by class (same ISBN)
Directional only; see caveats.
<table header-row="true">
<tr>
<td>Control</td>
<td>Level</td>
<td>Priced rows</td>
<td>Avg new</td>
<td>Min</td>
<td>Max</td>
</tr>
<tr>
<td>Public</td>
<td>2yr</td>
<td>266</td>
<td>\$41.92</td>
<td>\$31.50</td>
<td>\$158.70</td>
</tr>
<tr>
<td>Private NFP</td>
<td>4yr</td>
<td>7,775</td>
<td>\$40.36</td>
<td>\$5.00</td>
<td>\$159.05</td>
</tr>
<tr>
<td>Public</td>
<td>4yr</td>
<td>7,072</td>
<td>\$38.15</td>
<td>\$13.24</td>
<td>\$193.95</td>
</tr>
<tr>
<td>Private FP</td>
<td>4yr</td>
<td>614</td>
<td>\$34.54</td>
<td>\$32.00</td>
<td>\$37.32</td>
</tr>
</table>
> For this title, **public 2-year** averages the **highest** new-print price (\$41.92) — above public 4-year (\$38.15) and private for-profit 4-year (\$34.54) — consistent with the hypothesis, though within-class ranges are wide.
