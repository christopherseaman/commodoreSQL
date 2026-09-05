---
notion-id: 3ced9fdd-1a1a-81cf-979c-c0c82e965b1e
notion-url: https://app.notion.com/p/Course-material-populations-3ced9fdd1a1a81cf979cc0c82e965b1e
notion-sync: push
---

# Course-material populations

Flags/enrollment assignment: `2_oer_classification.sql`. Canonical grouping: `2b_course_material.sql`.

## Source and canonical grains

`comprehensive_data`: enriched source rows. Raw IPEDS/opt-out joins require unique lookup keys;
each refresh must prove row conservation.

`course_material`: group by `(period_sortable, section_id, ISBN13)` with NULL-safe ISBN equality.
Require non-NULL period/section; `UNKNOWN` components remain eligible. Rejected rows stay upstream.
Each section keeps its ISBN items plus at most one NULL-ISBN row; all-NULL sections have
`is_no_adoption_section=TRUE`. Section IDs include term.

## Authoritative row predicates

| Flag | Exact row rule |
|---|---|
| `is_recent` | Term appears in `recent_period`; NULL is false. |
| `has_isbn` | `ISBN13 IS NOT NULL`; blanks become NULL, numeric pseudo-SKUs remain. |
| `has_formattype` | `FormatType IS NOT NULL AND TRIM(FormatType) <> ''`. |
| `is_supply` | recent-term ISBN matches title classifier; unmatched/blank is false. |
| `no_details` | title exactly `*No Book Details*`. |
| `no_materials` | title exactly `*No Books Required*` or `supply_category='placeholder_no_material'`. |
| `is_canada` | state exactly `CAN`. |
| `is_course_material_use` | recent-term AND not Canada AND has ISBN AND not supply AND not no-details AND not no-materials. |
| `is_course_material_no_use` | recent-term AND NOT the Use predicate. |

Use/NoUse partition recent-term rows; both are false outside the window. Canada is NoUse. Exclusions may overlap.

`recent_period` selects the newest 12 distinct non-NULL catalog terms, shared with mailing.
Supply classification, requiredness inference, and enrollment context cover that same window.

recent-term required inference is true when:

- a section has a required non-supply row and this row is required; or
- no such row exists and this row's `book_status` is NULL.

Otherwise false. Pricing status/required fields remain independent.

## Canonical aggregation and conflicts

Booleans use `BOOL_OR`; OR/AND differences flag conflicts. Any Use source row routes its key to
Use; NoUse is `is_recent AND NOT has_use_source_row`. Retain:

- `use_source_row_count`, `no_use_source_row_count`;
- `has_use_source_row`, `has_no_use_source_row`;
- `population_classification_conflict`.

Representative order: Use, inferred required, stable fields. Term/ISBN title, author, and publisher
use lexical `MIN` plus variant counts.

## Routing

| Table / view | Population |
|---|---|
| `course_material_recent` | `is_recent` |
| `course_material_use` | `is_course_material_use` |
| `course_material_no_use` | `is_course_material_no_use` |
| Canada export | NoUse AND `is_canada`; direct filter, no relation |
| `master_material` | Every Use item, LEFT-enriched with pricing |
| `master_section` | Sections represented in `master_material` |
| `section_enrollment` | All valid recent-term sections, independent of ISBN/Use |

Excluded rows contribute only labeled audit counts; they cannot add release sections.

## Enrollment ownership

`section_enrollment` owns catalog enrollment/seats and availability; raw values use
`MAX`, and course-level ties resolve lexically. `comprehensive_data` adds IPEDS context
and assignment once; material/release tables inherit it. Never re-impute downstream.
The assignment ladder is documented in CMM Data Flow.

## Checks

- Enriched rows = source rows; count rejected admission keys.
- `SUM(source_row_count)` = admitted source rows; unique canonical keys/NULL audits.
- Raw distinct Use keys = `course_material_use` rows; views = flags.
- Valid Use/NoUse partition, no-adoption flags, and conflict evidence.
- Unique non-NULL enrollment keys; assignments agree with source signals.
