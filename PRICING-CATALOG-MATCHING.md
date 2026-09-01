---
notion-id: 3ced9fdd-1a1a-818d-b34e-f52788da8997
notion-url: https://app.notion.com/p/Pricing-to-catalog-matching-3ced9fdd1a1a818db34ef52788da8997
notion-sync: push
---

# Pricing-to-catalog matching (issue #21)

Status: **open and unimplemented**. The executable join remains exact. See
[#21: reconcile pricing and catalog section identity](https://github.com/christopherseaman/commodoreSQL/issues/21).

## Current contract

`course_materials_use` owns the canonical item population at
`(period_sortable, section_id, isbn13)`. `pricing_wide` is source-owned at
`(section_id, isbn13)`. `material_costs` preserves every canonical Use item and only LEFT-enriches:

```sql
LEFT JOIN pricing_wide pw
  ON cm.section_id = pw.section_id
 AND CAST(cm.isbn13 AS VARCHAR) = pw.isbn13
```

Pricing rows never add or redefine catalog items. `has_pricing_match` means this exact edge exists;
it does not mean a valid price exists. `2d_data_quality.sql` compares the sources without mutating
either. No normalization, CRN fallback, or broad-key match is currently used.

Catalog `section_id` uses catalog `Section`; pricing `section_id` uses pricing `Section Code` and
ignores the separately retained pricing `CRN`. Although both expressions concatenate UNITID,
department, course, section, and period, the source fields are not consistently equivalent.

## Current evidence from issue #21

Evidence is scope-labeled because the all-period pricing population and Fall 2025 canonical item
population answer different questions.

### All-period current-database pricing-section evidence

- 6,514,282 distinct pricing section IDs; 2,162,695 lack an exact catalog section-ID match.
- Case plus numeric-padding normalization finds 908,287 candidates; 906,798 are one-to-one in
  both sources, including about 753,205 required-section candidates.
- Blind zero stripping creates collision keys and is unsafe.
### Fall 2025 evidence

- Among 602 UNITID/bookstore-locator pairs outside the current Lineage 3 predicate, 249,827
  pricing sections lack an exact catalog match. CRN locates a catalog section for 101,172; 96,632
  also agree on normalized UNITID, department, and course.
- Within that pair scope, 122 current pricing `section_id` values contain two or three distinct
  CRNs. The present pricing key can therefore collapse distinct source offerings.
- The exact section × ISBN join matches 1,837,586 of 2,754,111 canonical Use items.
- A unit + term + ISBN existence test reaches 2,408,002 and identifies 570,416 potential
  recoveries, but a direct join at that broader key multiplies rows.

These figures diagnose the checked evidence; they are not evergreen baselines and must be
recomputed for a refreshed source.

## Mismatch modes and examples

| Mode | Example / risk |
|---|---|
| Section Code differs from catalog Section but CRN agrees | UC San Diego: pricing `A00`, catalog `912565`; Temple: `001` vs `33701`; Texas Tech: `001` vs `48426`. |
| Case difference | Department or course codes differ only by case. Safe only when uniqueness is proven. |
| Numeric padding | Course/section encodings differ by leading zeros. Global stripping can collide. |
| Institution-specific encoding | Department, course, or section fields represent different source concepts or concatenate components differently. |
| Multiple CRNs under one pricing section ID | One current key may represent distinct offerings; selecting a CRN without ambiguity handling can merge them. |
| Missing institution counterpart | No catalog UNITID/section exists, including source-scope differences such as Canada. No normalization can manufacture a counterpart. |
| Broader-key price multiplicity | Unit + term + ISBN may span bookstore URL, snapshot, option, condition, format, rental term, or multiple sections. A naïve fallback multiplies canonical items. |

Required-match analysis must use raw `book_status` or an independent catalog-match classification.
Using `is_required_inferred` to prove the old join harmless is circular because pricing can receive
catalog inference only after matching.

## Candidate strategies (none implemented)

1. **Exact first, then validated section crosswalk.** Normalize only proven case/padding variants
   and use source-aware Section Code/CRN mappings. Promote one-to-one edges; retain ambiguous,
   colliding, and missing candidates as explicit DQ states.
2. **Source-aware price dimension.** Pre-aggregate at `(unit_id, period_sortable, isbn13,
   bookstore_url, book_option, book_condition, book_format, rental_days)` after defining the latest
   snapshot rule, then join at a deliberately chosen catalog grain. This improves coverage but
   requires policy for section attribution and bookstore/snapshot conflicts.
3. **Conservative broader-key fallback.** Keep exact matches, then use unit + term + ISBN only when
   the mapping and pre-aggregated price row are unambiguous. Leave all other candidates unmatched.

Every strategy must preserve raw catalog `Section`, pricing `Section Code`, pricing `CRN`, source
and snapshot provenance, and an explicit match method.

## Decision and validation gates

No strategy may enter the executable contract until all gates pass:

1. Define the target canonical section-offering identity and crosswalk key.
2. Define safe normalization per source/institution; prove it does not merge distinct offerings.
3. Report exact, normalized, CRN-assisted, ambiguous/colliding, missing-UNITID, and no-counterpart
   results by period and raw pricing `book_status`, independent of inferred-required status.
4. Quantify one-to-one, one-to-many, many-to-one, and multi-CRN mappings. Only approved unique
   matches may be promoted automatically.
5. For broader matching, define and validate the pre-aggregation grain, latest-snapshot handling,
   bookstore conflicts, option/condition/format cells, and rental-term retention.
6. Reconcile exact, recovered, ambiguous, unmatched, matched-but-unpriced, and valid-price counts
   to the unchanged canonical Use denominator.
7. Prove no row multiplication and rerun item, section, institution, ISBN, cost, and export DQ.
8. Retain an exact-only comparison so coverage and cost changes can be attributed to matching,
   not a changed material population.
9. Update SQL, schema/lineage, and this contract together only after the decision is implemented.

Until then, unmatched canonical items remain in `material_costs` with
`has_pricing_match=FALSE`. See [`CMM-ETL.md`](CMM-ETL.md) for cost semantics and
[`DATA-DICTIONARY.md`](DATA-DICTIONARY.md) for columns.
