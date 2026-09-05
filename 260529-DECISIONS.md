# CommodoreSQL — Decisions Log (2026-05-29)

Decisions made while building the roadmap data model and triaging the reporting/backlog
issues. Branch: `data-model-derived-columns`. Board: https://github.com/users/christopherseaman/projects/2

Each decision lists the **choice** and **why**. Where a default was assumed (rather than
confirmed), it is marked **[assumed]** and is open to revision in the issue's Review.

Current contracts supersede this snapshot: `master_section` now owns section-cost
aggregation (#84), and `schema.dbml` is current. See `CMM-ETL.md`.

---

## 1. Data model — section & course derived columns (#1–#8, in Review)

### #1 — required / non-required classification
- **Decision:** A material is *required* iff `book_status = 'required'` **OR** (the section has
  no required material **AND** `book_status IS NULL`). Implemented by **reusing
  `comprehensive_data.filter_include`** rather than re-deriving the rule.
- **Why:** matches Notion Reporting Assumptions §5 and the existing pipeline; DRY (one rule).
- **Consequence:** `filter_include` is gated on `period_date >= 2024`, so **`master_section`
  is scoped to 2024+** (pre-2024 = 68.8% of rows, out of analytical scope; reporting only
  covers 2024/2025/2026). `master_course` and the `31/32_master_*` exports inherit 2024+.
- `recommended` / `option` are **always** non-required (even in no-required sections).
- Fixed a latent bug: blank-status rows previously counted as *neither* required nor optional
  (`NULL != 'required'` is `NULL`). Now `required_count + optional_count = material_count`.

### #2/#3/#4 — section cost columns (superseded by #84)
- **Decision at the time:** A materialized `section_cost` table computes cost over **distinct
  `(section_id, ISBN13)` materials** (dedupe before summing, since a book can appear in
  multiple catalog rows).
- `required_cost_total_min/max`, `optional_cost_total_min/max` = `SUM` of per-material
  `price_min/max`, split by `filter_include`.
- `*_cost_owned_min/max` = buy-only (rentals omitted), from new
  `pricing_wide.price_buy_min/max`.
- `*_cost_avg = (min + max) / 2` — the **legacy `price_avg` convention, NOT an arithmetic
  mean** (labeled in SQL). Three avgs per Notion: required, required-owned, optional.
  `optional_cost_owned_avg` omitted (raw min/max available).
- **NULL-price handling [assumed]:** materials with no matched price contribute nothing
  (`SUM` skips NULL); `required_priced_count` / `optional_priced_count` (section level) expose
  coverage so partial cost is visible. **Caveat (verification):** `priced_count` counts
  materials with *any* price (total coverage), **not owned-only** — ~682k sections have a
  non-NULL total cost but NULL owned cost (their priced materials are rental-only), so
  `priced_count` is not the right coverage denominator for the `*_owned_*` columns.
- **owned ≠ subset of all-options:** owned sums only buy-priced materials (a smaller set), so
  `owned_min` can be *less* than `total_min`. Intended.

### #6 — course cost rollup
- **Decision [assumed]:** `master_course` rolls up section cost via
  **`MIN(min) / MAX(max) / AVG(avg)`**, **not `SUM`**.
- **Why:** sections of a course usually share the same book; summing would multiply a shared
  material's cost (a $100 text in 3 sections is $100, not $300). MIN/MAX give the cross-section
  range; AVG the typical.
- Course-level `priced_count` **dropped** (a `MAX`-of-section-counts read like a count —
  ambiguous; flagged in code review). Section-level coverage remains.

### #5/#7 — OER / Inclusive Access
- **Decision:** `is_oer`/`is_ia = COALESCE(BOOL_OR(...), FALSE)`, `oer_count`/`ia_count =
  COUNT(*) FILTER (...)`, over **all** section materials (Notion "any items" / "items listed",
  not split by required). Course rollup: `BOOL_OR` indicators, `SUM` of section counts.
- Invariant held & DQ-checked: `is_oer <=> oer_count > 0`.

### #8 — course section count + seat sum
- **Decision:** satisfied by existing columns — `section_count = COUNT(DISTINCT section_id)`,
  and **both** `seats_taken_total` and `enrollment_total` exposed.
- **[assumed]** seat sums left as `NULL` where a course has no seat data (not `COALESCE`d to 0,
  to keep "no data" honest). Coverage: `seats_taken_total` NULL for 45.8% of courses,
  `enrollment_total` NULL for 29.5%. **Open for Review:** which field is "seats", NULL vs 0.

### Grain caveat (→ #24)
- `master_section` / `master_course` are **not unique** per `section_id` / `(course_id,
  period)` — descriptive columns (`course_title`, `course_level`, `course_subject`) vary within
  a key due to source noise (0.13% of section_ids split). Cost is attached at the natural key
  and **repeats** on the split rows (read via the key; don't `SUM` across split rows). Collapsing
  the grain was **deferred** to #24 to avoid changing already-validated #1/#5 output.

---

## 2. Pricing layer refactor

- **Decision:** `pricing_wide` is now the **unfiltered base** (all priced materials),
  materialized as a **TABLE**; `pricing_wide_filtered` is the **required subset**
  (`filter_include`) as a **VIEW**. Added `price_buy_min/max` (owned).
- **Why:** the cost columns need prices for **non-required** materials, which the old
  required-only `pricing_wide` lacked. `pricing_wide_filtered` preserves prior semantics for
  existing consumers (`2d_data_quality.sql`); verified its row count matches the old
  `pricing_wide` (5,972,929).
- This historical pricing-layer description has since been superseded. The current matching
  contract and evidence live only in the
  [CMM-ETL issue #21 limitation](CMM-ETL.md#current-limitation--pricing-to-catalog-section-matching-issue-21).

---

## 3. Reporting filter layer (#9–#13) — **deferred**, assumptions recorded

These are Metabase parameter/UX decisions ("Reporting Assumptions" — the project team's call)
and the `metabase/` tree has active uncommitted WIP. Building speculative parameters now risks
colliding with that WIP, so the **build is deferred to a focused Metabase session**. Assumed
designs (ready to build):

- **#9 time** — term multi-select over `period_sortable` (2024-1 … 2026-4); per-term vs
  aggregate via a separate toggle. `period_date` for time axes.
- **#10 geography** — US / region / state / IPEDS `unit_id`. **Needs a `state → region`
  lookup** (no region column); **[assumed]** US Census 4 regions / 9 divisions. Build the
  lookup as a small reference table in the pipeline.
- **#11 institutional** — `control`, `iclevel`, `instsize` (string descriptors, not codes);
  `enroll_24` & `dist_enroll_24` numeric ranges; distance % = `dist_enroll_24 / enroll_24`
  (guard divide-by-zero / NULL).
- **#12 course** — `course_level` (map to intro/intermediate/advanced/graduate — **[assumed]**
  needs value-set confirmation), `course_subject`, specific `course_id` list.
- **#13 material** — required and/or optional, consistent with #1's classification.

---

## 4. Visualization — questions & dashboards (#14–#18) — **deferred**, assumptions recorded

Depends on the now-built cost/OER columns. Deferred for the same reason as filters (live
Metabase app + active `metabase/` WIP; dashboard JSON is ID-managed via `sync.py` and is
error-prone to hand-author). Assumed scope:

- **#14 cost questions** — required/optional cost min/max/avg distributions; owned-vs-all;
  course-level summaries. Backed by `master_section` / `master_course` cost columns.
- **#15 OER/IA questions** — adoption rate + item-count distributions, section & course.
- **#16/#17 dashboards** — Course Materials Cost; OER/IA Adoption (extend existing
  `oer_ia_status_filtered`).
- **#18 master report** — host #9–#13 filters across the cost + OER/IA cards.

---

## 5. Backlog (#19–#24)

- **#19 persistent DQ logging — [assumed] resolved by existing WIP.** `2d_data_quality.sql`
  already writes to a `__data_quality_metrics` table (+ side tables). That is the chosen
  persistent surface. Verify + close once that WIP is committed.
- **#20 NULL-ISBN — [assumed] resolved by existing WIP.** `2d`'s
  `__data_quality_null_isbn_breakdown` identifies the only 3 placeholder strings for NULL-ISBN
  rows (`*No Book Details*` ~92%, `*No Books Required*` ~7.4%, `*Bad Course*` ~0.03%) — none are
  "real missing". **Rule:** NULL-ISBN = no book adopted; retain for section/enrollment counts,
  exclude from ISBN-level joins (current item and section layers already do this).
- **#21 pricing↔catalog `section_id` normalization — superseded here.** See the current contract,
  evidence, and pending alternatives only in the
  [CMM-ETL issue #21 limitation](CMM-ETL.md#current-limitation--pricing-to-catalog-section-matching-issue-21).
- **#23 contemporaneous Amazon prices — deferred (someday).** Needs an external data source;
  out of scope for the current dataset.
- **#24 merged-records consistency follow-ups:**
  - **`master_course_material` 2024+ scope — [assumed] yes.** Scope it to `period_date >= 2024`
    to match `master_section`/`master_course` (apply in the next DB-write pass; one-line WHERE).
  - **`section_id` grain uniqueness — deferred.** Collapse to one row per `section_id` (and
    `master_course` per `(course_id, period)`) is a larger change; revisit when it blocks work.
  - **publisher-split alignment — deferred.** `required_publishers` etc. still use
    `LOWER(book_status)='required'`; align to `filter_include` after the grain fix (distinct
    counts aren't additive across the split).
  - **2026-09-04 disposition:** retain `master_course` and export 32 for the requested course×term
    rollup. `enrollment_total` sums raw `master_section.enrollments`; assigned enrollment is not
    substituted. Retire tentative `master_course_material` and export 33; no consumer was found.
  - **`schema.dbml` drift — resolved.** Current definitions are generated from the implemented flow.

---

## 6. Historical schema proposal (superseded)

New table **`section_cost`** (1 row per `section_id`): `course_id`, `period_sortable`,
`required_cost_total_min/max`, `optional_cost_total_min/max`, `required_cost_owned_min/max`,
`optional_cost_owned_min/max`, `required_priced_count`, `optional_priced_count`.

**`master_section`** new columns: `is_oer`, `is_ia`, `oer_count`, `ia_count`,
`required_cost_total_min/max`, `optional_cost_total_min/max`, `required_cost_owned_min/max`,
`optional_cost_owned_min/max`, `required_cost_avg`, `required_cost_owned_avg`,
`optional_cost_avg`, `required_priced_count`, `optional_priced_count`. Now 2024+ scope.

**`master_course`** new columns: `is_oer`, `is_ia`, `oer_count`, `ia_count`, + the same cost
totals/owned/avg (rolled up MIN/MAX/AVG; no priced_count).

**`pricing_wide`** is now a TABLE (all materials) with `filter_include`, `price_buy_min`,
`price_buy_max` added; **`pricing_wide_filtered`** is a new VIEW (required subset).

---

## 7. Cross-cutting

- **Board workflow:** Status = `Todo → On Deck → In Progress → Review → Done`. **Review = human
  review, set only after Claude self-validates;** the human owns `Review → Done`.
- **Validation discipline:** every data-model issue went RED→GREEN TDD against the real 71GB
  DuckDB + an independent code review, with permanent pipeline DQ invariants
  (`master_section/master_course reconciliation`, `OER/IA invariant`, `cost min<=max`).
