---
notion-id: 3ced9fdd-1a1a-818d-b34e-f52788da8997
notion-url: https://app.notion.com/p/3ced9fdd1a1a818db34ef52788da8997
notion-sync: push
---

# Pricing Matching

In general, prices should *probably* agree **within an institution at a timepoint**, holding ISBN
and offer terms constant. Differences between institutions are expected; no strategy
below borrows prices across institutions.

## Two populations

Fall 2025 has **5,459,527 retained pricing observations**, grouped into **2,510,652
section × ISBN pricing keys**. Of those keys, 1,854,709 have an exact catalog key:
1,837,586 are canonical Use and 17,123 are intentional NoUse. The other **655,943
pricing keys have no exact catalog counterpart**: 474,980 have a valid-key
institution × term × ISBN Use candidate, 4,238 have only a NoUse candidate, 45,111
have an invalid unmatched pricing composite/identifier, and 131,614 have no institution × term ×
ISBN catalog source. Those categories account for 1,227,394 retained observations.

The opposite denominator is **2,754,111 canonical Use material keys**, formed from
2,757,330 catalog source rows after section × ISBN grouping. Exact pricing covers
1,837,586; the **916,525 Use keys without exact pricing** split into 560,758 with a
valid-key pricing institution × term × ISBN candidate and 355,767 with no such pricing
source. Separately, grouping produces 3,555,745 NoUse keys; their exclusion reasons
overlap (for example, no-ISBN and no-material markers) and are not missing-price causes.

The 570,416 unrestricted and 512,589 guarded figures below use unmatched **Use
material keys**, not raw-pricing rows or keys. The unrestricted total is 9,658 higher
than the valid-key candidate bucket above because it permits institution-level evidence
from pricing rows whose exact composite key contains an invalid/`UNKNOWN` segment.
That overlap is visible diagnostically and is not an approved match.

Institution × term × ISBN agreement narrows the candidate pool but does not prove
which section, department, course, or CRN encoding caused the exact mismatch. Known CRN
examples below are separate evidence. Exact section × ISBN matches always retain current
production semantics, including when a composite contains `UNKNOWN`; invalid-key labels
apply only after exact matching fails.

## Strategies versus current

Fall 2025: **2,754,111 materials**. Current counts are observed; alternative totals assume
accepting every candidate under that strategy, before further validation. Three existing
matches lack valid prices; every additional candidate has some valid price. Strategies overlap.

| Strategy | Additional matches | Resulting matched | Remaining unmatched | Possible issues |
|---|---:|---:|---:|---|
| **Current: exact section × ISBN** | — | 1,837,586 | 916,525 | Encoding mismatches; derived pricing IDs can already collapse multiple CRNs. |
| **Exact-first, any institution × term × ISBN** | 570,416 | 2,408,002 | 346,109 | 49,900 varying payloads; 10,120 multiple-store candidates (overlapping). Direct joining multiplies rows. |
| **Exact-first, identical payload + one source bookstore** | **512,589** | **2,350,175** | **403,936** | 178,932 have one source section; 328,842 span multiple timestamps. Raw-offer/product checks remain. |
| **Above, also one recorded source timestamp** | 183,747 | 2,021,333 | 732,778 | Sacrifices coverage without establishing a catalog-aligned timepoint. |

Two unquantified alternatives: **section normalization/CRN crosswalks** repair offering
identity but risk collisions unless mappings are one-to-one; **institution-price-first**
at a chosen as-of time could standardize prices but replace existing exact prices.
Unlike these alternatives, the measured fallbacks preserve every existing match and item key.

## Unexpected findings

- **Same-time prices mostly agree, but not always:** 553 of 171,309 repeated
  institution/ISBN/offer/timestamp/bookstore groups disagree (**0.32%**). Alabama AC 371
  sections 005/006 show $33 versus $133 for identifier `9780013869771`, buy/new/digital,
  at `2025-11-03 21:52:06`. Neither price is established as correct.
- **Unanimous peers can differ from the exact match:** hiding the exact section for
  1,333,005 matched items leaves unanimous peers agreeing for 1,175,730 and disagreeing
  for 25,617. This term-level comparison is not a same-timepoint error rate.
- **Current processing hides context:** import selects latest per section/ISBN/offer/rental
  duration, not a common snapshot. CRN/bookstore are outside that partition; ties are
  arbitrary. `pricing_wide` drops timestamps, selects MAX URL, and collapses rental durations.
  Its URL alone falsely admits 82 candidates to the single-store pool.
- **Matching summary bounds is insufficient:** 4,553 varying-payload candidates have
  identical bounds. Also, 1,342 candidates use non-13-digit identifiers; 13 digits alone
  does not establish product identity.

## Recommendation

**Recommend a shadow test of exact-first, identical-payload, single-store fallback:**
up to 512,589 additional matches while preserving existing exact prices. Do not activate
the unrestricted fallback or replace exact prices with institution-wide prices yet.

Derive one candidate per institution × term × product within material enrichment; retain
catalog keys/metadata and label the match method. Check retained tall offers before pivoting,
since identical wide payloads can conceal rental-detail differences. Choose staleness and
single-section evidence rules, quarantine product/conflict cases, then compare coverage and
section/course costs. Never average away conflicts or borrow across institutions.
No new release table is needed.

## Measurement notes

Payload includes all 18 price cells, four bounds, rental-day bounds, format count, and
buy/rental presence, including NULL differences. Offer comparisons hold option, condition,
format, and rental duration constant; valid price follows SQL (`price < 9999`), including zero.
Consistency excludes NULL/`0` identifiers and requires multiple sections; coverage retains
existing material identifiers. Agreement is a selected-group statistic, not item-level accuracy.

Earlier observations discarded by import were not reloaded. Historical section-encoding
evidence remains in #21. Reproduce using `scripts/diagnostics/pricing_match_coverage.sql`
and `scripts/diagnostics/pricing_offer_consistency.sql`; reproduce the two-direction counts,
grouping/filter boundary, and examples with
`scripts/diagnostics/pricing_population_accounting.sql`. Each header gives its read-only command.
No ETL or data changed.
