---
notion-id: 3ced9fdd-1a1a-81cf-979c-c0c82e965b1e
notion-url: https://app.notion.com/p/Course-material-populations-3ced9fdd1a1a81cf979cc0c82e965b1e
notion-sync: push
---

# Course-material populations (#58 and #65)

This page defines the implemented source-to-canonical population contract. SQL remains
authoritative: `scripts/sql/2_oer_classification.sql` owns row flags and
`scripts/sql/2b_course_materials.sql` owns canonicalization and enrollment.

## Source and canonical grains

`comprehensive_data` preserves exactly one enriched row for every normalized BMG catalog row in
the recorded count-preserving snapshot. Its SQL directly joins raw `opt_out` and `ipeds_data`
without enforcing or collapsing duplicate lookup keys; every refresh must prove lookup-key
uniqueness and source-row conservation.
`course_materials` accepts rows with non-NULL `period_sortable` and `section_id`, then groups with
NULL-safe ISBN equality at:

```text
(period_sortable, section_id, ISBN13)
```

The result is one canonical item per non-NULL ISBN key and at most one NULL-ISBN audit row per
section. Canonical admission requires only non-NULL `period_sortable` and `section_id`; composite
components encoded as `UNKNOWN` are not excluded and can remain in canonical rows. Rows missing
either admission key remain in `comprehensive_data` and are reported by DQ rather than represented
canonically. `source_row_count` must reconcile canonical groups to all valid source rows.

`section_id` already contains the period, but `period_sortable` remains an explicit key and release
dimension. A section with both ISBN and NULL-ISBN rows retains its ISBN items plus one NULL audit
row. A section whose only rows have NULL ISBN has `is_no_adoption_section=TRUE`.

## Authoritative row predicates

| Flag | Exact row rule |
|---|---|
| `is_post_2024` | `period_date >= DATE '2024-01-01'`, with NULL treated as false. |
| `has_isbn` | `ISBN13 IS NOT NULL`. Blank configured CSV values arrive as NULL; numeric pseudo-SKUs remain non-NULL. |
| `has_formattype` | `FormatType IS NOT NULL AND TRIM(FormatType) <> ''`. |
| `is_supply` | ISBN matched the 2024+ title keyword classifier; unmatched/blank ISBN is false. |
| `no_details` | title exactly `*No Book Details*`. |
| `no_materials` | title exactly `*No Books Required*` or `supply_category='placeholder_no_material'`. |
| `is_canada` | state exactly `CAN`. |
| `is_course_material_use` | post-2024 AND not Canada AND has ISBN AND not supply AND not no-details AND not no-materials. |
| `is_course_material_no_use` | post-2024 AND NOT the Use predicate. |

Use and NoUse partition every post-2024 source row exactly once; both are false before 2024.
Canada is always NoUse. The five exclusion facts—Canada, missing ISBN, supply, no-details, and
no-materials—can overlap and remain separate booleans. No single exclusion reason is authoritative.

Required inference is catalog-owned. For 2024+ rows it is true when either:

- the section has any `book_status='required'` non-supply row and this row is required; or
- the section has no such row and this row's `book_status` is NULL.

It is false otherwise. Pricing `book_status` and `required` are independent source fields.

## Canonical aggregation and conflicts

For each key, definitive boolean fields use `BOOL_OR`; corresponding OR/AND disagreements are
stored as conflict flags. Canonical Use is true if any source row in the key is Use. Canonical
NoUse is `is_post_2024 AND NOT has_use_source_row`, so a key with both Use and NoUse source rows is
routed to Use while preserving:

- `use_source_row_count`, `no_use_source_row_count`;
- `has_use_source_row`, `has_no_use_source_row`;
- `population_classification_conflict`.

The representative row is selected deterministically, preferring Use, then inferred required,
then stable source/catalog fields. This selects metadata; it does not erase multiplicity.
`source_row_count`, field variant counts, `catalog_metadata_conflict`,
`contact_metadata_conflict`, and individual boolean conflict flags expose disagreement.
Term/ISBN title, author, and publisher metadata use lexical `MIN` plus variant counts.

## Published population views and routing

| Relation | Filter | Downstream use |
|---|---|---|
| `course_materials_post_2024` | `is_post_2024` | all canonical 2024+ item/audit groups |
| `course_materials_use` | `is_course_material_use` | release material spine; input to `material_costs` |
| `course_materials_no_use` | `is_course_material_no_use` | excluded/audit population |
| `course_materials_canada` | NoUse AND Canada | Canadian audit/export subset |
| `material_costs` | all `course_materials_use` rows, LEFT pricing enrichment | item-level release and cost input |
| `master_section` | sections represented by `material_costs` | material-bearing section release denominator |
| `section_enrollment` | all valid 2024+ sections | complete section/enrollment denominator |

Supplies, placeholders, Canada, missing ISBNs, and pre-2024 rows never enter `material_costs`.
Excluded rows may appear only as explicitly labeled audits. They do not enlarge the
`master_section` denominator.

## Enrollment ownership

`section_enrollment` is one row per valid 2024+ `section_id`, built independently of ISBN and Use.
It owns raw section enrollment, coverage flags, course/scope dimensions, `enrollment_assigned`,
and `enrollment_source`. Raw section signals use `MAX(enrollments)` and `MAX(seats_taken)`; equally
frequent course-level labels resolve lexically.

Assignment order is own enrollment, usable own seats (`<9999`), course × period enrollment
median, course × period usable-seats median, control × level × period enrollment median, then
level × period enrollment median. Medians use the defined four-course-level × six-sector BMG
reference population. `course_materials` receives these fields by exact period + section join;
downstream relations must not independently impute enrollment.

## Core DQ gates

- enriched catalog row count equals normalized source row count;
- NULL period/section admission keys are counted; UNKNOWN composite components are not an exclusion gate;
- `SUM(course_materials.source_row_count)` equals valid source rows;
- non-NULL canonical keys and per-section NULL audit rows are unique;
- NULL source rows are conserved and `is_no_adoption_section` is consistent;
- post-2024 Use/NoUse partition violations and pre-2024 flag violations are zero;
- raw distinct Use keys equal `course_materials_use` rows;
- view row counts equal their stored-flag counts;
- conflict flags equal their underlying OR/AND or source-count conditions;
- `section_enrollment` keys are unique/non-NULL and assignment values agree with sources.

See [`CMM-ETL.md`](CMM-ETL.md) for the release contract and
[`DATA-DICTIONARY.md`](DATA-DICTIONARY.md) for every field.
