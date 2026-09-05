---
notion-id: 3ced9fdd-1a1a-818d-b34e-f52788da8997
notion-url: https://app.notion.com/p/Pricing-to-catalog-matching-3ced9fdd1a1a818db34ef52788da8997
notion-sync: push
---

# Pricing mismatch

[Issue #21](https://github.com/christopherseaman/commodoreSQL/issues/21) is unimplemented. Matching remains exact.

## Current contract

`master_material` retains every `course_material_use` item and LEFT-enriches:

```sql
LEFT JOIN pricing_wide pw
  ON cm.section_id = pw.section_id
 AND CAST(cm.isbn13 AS VARCHAR) = pw.isbn13
```

Both sides are unique at section × ISBN; section includes term. Pricing never creates catalog
items. Match ≠ valid price. `2d_data_quality.sql` compares sources without mutation.

IDs concatenate UNITID, department, course, section, period. Catalog uses `Section`; pricing uses
`Section Code`, ignoring retained `CRN`. These fields can identify different things.

## Evidence

Recorded diagnostics; recompute after refresh.

| Scope | Finding |
|---|---|
| All periods | 6,514,282 pricing section IDs; 2,162,695 unmatched. |
| Case/padding candidates | 908,287 candidates; 906,798 one-to-one, including ~753,205 required-section candidates. |
| Fall 2025: 602 pairs excluded by the former Lineage 3 predicate | 249,827 unmatched sections; CRN finds 101,172, of which 96,632 agree on normalized UNITID/department/course. |
| Same 602-pair scope | 122 pricing IDs contain 2–3 CRNs: distinct offerings can collapse. |
| Fall 2025 Use items | Exact join: 1,837,586 / 2,754,111. |
| Fall 2025 unit + term + ISBN existence | 2,408,002 matches; 570,416 potential recoveries. Direct joining multiplies rows. |

## Causes

| Mode | Example / risk |
|---|---|
| Section Code vs Section; CRN agrees | UC San Diego: `A00` vs `912565`; Temple: `001` vs `33701`; Texas Tech: `001` vs `48426`. |
| Case/padding | Normalization may collide; global zero stripping is unsafe. |
| Institution-specific encoding | Department/course/section components have different meanings or concatenation. |
| Multiple CRNs per ID | Selecting one can merge offerings. |
| Missing UNITID/section | No counterpart exists, including scope differences such as Canada. |
| Broader price key | Multiple bookstores, snapshots, offers, rental terms, or sections can multiply items. |

Analyze raw `book_status` or independent classifications. Catalog-derived inference is circular
as match evidence: obtaining it already requires a match.

## Options — none implemented

1. Section crosswalk: exact first, then proven case/padding/CRN mappings; promote only one-to-one.
2. Price dimension: aggregate `(unit_id, period_sortable, isbn13, bookstore_url, book_option,
   book_condition, book_format, rental_days)`; define snapshot and section-attribution policies.
3. Broader fallback: exact first, then unambiguous, pre-aggregated unit + term + ISBN.

Preserve raw `Section`, `Section Code`, `CRN`, provenance, and match method.

## Before implementation

- Define identity, crosswalk, and source-specific normalization; prove no offering collisions.
- Count exact, normalized, CRN, ambiguous, missing-UNITID, and no-counterpart matches by term/raw status.
- Quantify 1:1, 1:many, many:1, multi-CRN mappings; promote approved unique matches only.
- Validate aggregation grain, snapshots, bookstore conflicts, offer cells, and rental terms.
- Reconcile recovered/ambiguous/unmatched/unpriced/valid-price counts to unchanged Use keys; retain exact-only comparison.
- Prove no multiplication; rerun item/section/institution/ISBN/cost/export checks; update SQL/schema/docs together.
