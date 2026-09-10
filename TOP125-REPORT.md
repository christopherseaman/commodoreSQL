---
notion-id: 381d9fdd-1a1a-81a8-afcc-e187af8f6d11
notion-url: https://app.notion.com/p/sqrlly/381d9fdd1a1a81a8afcce187af8f6d11
notion-sync: push
---

# Top-125 ISBN Price Extract — Fall 2025

[Open report](https://meta.badmath.org/question/125) · Metabase card 125.

## Population

- Source: `master_material`; one canonical term × section × ISBN adoption.
- Fall 2025 (`period_sortable = '2025-4'`). Rank ISBNs by distinct section count;
  select 125, then return their Fall-2025 adoptions.
- Required and optional Use items are included, including unmatched/unpriced items.
- Catalog duplicate rows are already consolidated. Contact fields describe the
  selected canonical representative, not a separate row for every co-instructor.

## Fields and pricing

Institution, course, selected contact, requiredness/classification, bookstore URL,
18 buy/rental option prices, min/max and buy-only bounds, rental terms, and availability.
Pricing is inherited from `master_material`'s upstream exact section × ISBN LEFT join
to `pricing_wide`; the report does not join raw catalog or pricing records.

NULL price bounds mean no valid price, whether unmatched or matched with invalid-only
prices. Use `price_min IS NOT NULL` for valid-price-only analysis. `has_buy` and `has_rent`
indicate option presence, not necessarily a valid price. Each section adoption contributes
one row; institution-level comparisons need an explicit weighting choice.

The earlier exploratory counts and examples are historical, preserved locally in
`comms/top125-report-before-canonical-update.md`; they are not current report results.
