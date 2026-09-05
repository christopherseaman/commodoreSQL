# BMG Fall 2025 Cost Analysis — Decisions, Outputs & Review Notes

> 🔗 **In Notion (this doc mirrors that page):** https://app.notion.com/p/396d9fdd1a1a8183a35deb3117511e51

Reference summary of the Bay View Analytics (Jeff Seaman) grant course-materials cost
analysis. Organized by **decisions**, **outputs** (grouped conceptually), and **points of
note & review**. For the chronological build log see the Notion page *"26.06.26 · Fall 2025
Subsets A/B (BMG)"*; for the data model see `SCHEMA.md` / `schema.dbml`; for pickup see
`HANDOFF.md`. As of **2026-08-27**.

## TL;DR

- **Scope:** Fall 2025 (`period_sortable='2025-4'`), 4 undergrad course levels × the 6 real
  IPEDS teaching sectors. The current material-cost-derived Master Section contains **984,588
  material-bearing sections**: **Set A** (≥1 required Use material) = **858,147** and
  **Set B** (optional-only) = **126,441**. No-adoption/full-spine sections are outside this
  current Master Section population.
- **Prior hypothesis-test headline:** Public 2-year students faced **~$149/student** in required
  materials vs **~$114** for Public 4-year (**+31%**) — with the gap attributed to **course-mix**,
  not paying more for the identical book (same-item premium was only ~$2). Re-run this analysis
  before treating those dollar figures as refreshed for the current material-bearing scope.
- **Status:** the BMG initial-analysis backlog (#32, #34–#41) is complete and marked **Done**
  on the project board. The canonical Use/material-cost flow is implemented; #26 remains a
  held PI decision about owned-cost labeling.

---

## 1. Decisions

### Scope & subset definition (#35)
- **"Required code" = `is_required_inferred`** (issue #1's inferred-required; renamed from
  `filter_include`, #34). Set A = `required_count > 0`, Set B = `required_count = 0`, where
  `required_count` counts canonical `material_costs` items where `is_required_inferred` is true.
  The #58 Use flag additionally excludes Canada, missing ISBN, `no_details`, and `no_materials`.
  In the current material-cost-derived Master Section, Set B means optional-only material-bearing
  sections; no-adoption sections are not represented.
- **Sector = a whitelist of the 6 real teaching sectors** (not Jeff's exclude list). Equivalent
  to "exclude Jeff's list." The earlier full-spine accounting additionally dropped 128,780
  blank/unmatched-sector sections (no IPEDS match) and IPEDS sector 0 (Administrative Unit) —
  neither is a teaching institution.
- **Class cut = `control` × `level` (2yr/4yr)**, not `institution_type` (which carries source
  typos "Priavte"/"Profit"). The 6-way `sector` is available where a finer cut is wanted.
- **Set B is optional-only** (`required_count = 0` among material-bearing sections). The earlier
  full-spine implementation included no-adoption sections in Set B; that is a historical scope
  definition and is not the current Master Section population.

### Supply classification (#36) & the #41 fold-in
- **Title-keyword classifier, not FormatType** — `FormatType` (Book/eBook/Bundle/…, ~54% blank)
  does not encode supplies, so an **include-AND-NOT-exclude** title-keyword classifier is used.
- **Precision over recall (~0.98)** — a false positive would drop a real textbook, so broad
  keywords are kept with explicit *exclude* overrides (e.g. `calculator` kept, not dropped)
  rather than removed. Recall is intentionally keyword-bounded.
- **Classify once over all 2024+ title variants** of an ISBN (not per-analysis-window), so the
  flag is stable and reusable across periods.
- **In-place exclusion, not parallel columns** — supplies are excluded from the canonical
  `material_costs` item spine, and `master_section` consumes that spine. Any
  all-source supply audit belongs to `comprehensive_data`, not to the material-bearing section
  denominator.
- **#41 resolution = narrow fold-in, not blanket exclusion nor document-only.** The pseudo-SKU
  audit found **~90%** of the 436k pseudo-SKU "required" rows are **legitimate** required
  digital-access materials (Cengage/Pearson MyLab/WebAssign/iClicker) — kept. Two precision-
  verified gaps folded into the classifier: `eyewear` (science_lab) and 12 explicit "no material
  required" phrases (new **`placeholder_no_material`** category). Risky candidates rejected on
  verified collisions ('do not purchase' co-occurs with Inclusive-Access; bare 'no book'/'no
  text' hit piano/soprano method-book titles).
- **Placeholders routed through the existing `is_supply` mechanism** (with a distinguishing
  `supply_category`), not a separate flag — DRY/KISS, one code path.

### Enrollment fill (#32)
- **Persisted on `master_section`** (`enrollment_assigned`/`enrollment_source`), not left as an
  analysis-layer query — per the enrichment principle (derived columns live on the model).
- **6-rung hierarchy, own-before-borrowed:** own → own_seats (<9999) → sibling_enroll →
  sibling_seats → class_median (control×level) → level_median. Provenance in `enrollment_source`.
- **Medians per period over the `section_enrollment` scope reference population** (4 course levels
  × 6 teaching sectors), while the current reported assignment metrics below are for the
  material-bearing BMG section population.
- **Medians, not means** (resist the right-skew of the enrollment distribution); raw `enrollments`
  is never overwritten.

### `is_required_direct` correctness (#40)
- **Direct requiredness is supply-aware:** `BOOL_OR(book_status='required' AND NOT is_supply)`, so a
  supply-only "required" item (e.g. safety goggles) no longer hides a co-listed real textbook.
- **Supply classifier moved to a new upstream stage `1a_`** so `1b_` can consult it.
- **Shipped alone**, in its own window, ahead of #34/#41 — it was surfaced by adversarial review
  of the #32/#36 diff and the fix is a correctness change, not a rename.

### Analysis method (hypothesis test, #33/#39)
- **Same-item cost = demeaned price:** each priced adoption's `price_min` minus that ISBN's
  cross-institution median (ISBNs with ≥10 adoptions), aggregated by class — isolates same-item
  price from course-mix and book-identity confounds. (Ratios were rejected as outlier-fragile.)
- **Enrollment-weighted cost reports three variants** — headline enroll-weighted mean, own-only
  (imputation sensitivity), and p99-winsorized (outlier robustness) — so the +31% finding is
  shown robust rather than resting on one number.

### Rename (#34) & delivery (#39)
- **`filter_include` → `is_required_inferred` model-wide**, semantics-preserving; word-boundary
  swap that preserved filename stems and left the frozen `260529-DECISIONS.md` on the old name.
- **Self-serve = Metabase Models + GUI dashboards**, not "SQL editor first" — Jeff's real ask was
  GUI interactivity without SQL. Filters live on the Models (which carry every column), not
  retrofitted onto the fixed-scope tally cards.

### Process
- **Adversarial pre-write review before every heavy DB write** (workflow-orchestrated). It caught
  the `MATERIALIZED` 4× recompute, the historical #24 course-summary inconsistency, and #40 itself.
- **One rebuild window per coordinated change** (Metabase holds the DB file lock) — #40 in its own
  window, #34+#41 bundled into one.

---

## 2. Outputs (grouped conceptually)

### A. Data model (pipeline / DuckDB)
- **New pipeline stage `1a_supply_classification.sql`** → table `supply_isbn_classification`
  (ISBN-level, 2024+ title variants; currently **2,520 supply ISBNs** / 96,685 catalog rows).
- **`comprehensive_data`** gained `is_supply`, `supply_category`, and `is_required_inferred`
  (renamed from `filter_include`), followed by the canonical #58 population booleans and direct
  post-2024 Use/NoUse/Canada views.
- **`master_section`** is the material-cost-derived section rollup: one row per section represented
  by canonical `material_costs` Use items. Section enrollment fields arrive through
  `comprehensive_data` → `course_materials` → `material_costs` (#32). Material counts/costs (`material_count`,
  `required_count`, `optional_count`, OER/IA, coverage, publishers, and cost columns therefore
  share the same material-bearing section population. The independent
  `section_enrollment` table retains the broader valid 2024+ section spine.
- **`master_course`** is retained for the requested course×term rollup (export 32); its `enrollment_total` sums raw
  `master_section.enrollments`, while `master_section.enrollment_assigned` remains available upstream.
- **`master_course_material` and export 33 are retired:** the tentative publisher/status output had
  no consumer, excluded NULL publishers, and repeated seats across publisher/status groups.
- **`master_section_us_intro_fall2025`** view (#38): Fall 2025, US-only, intro/intermediate,
  `required_count>=1` — a pure filtered projection of the material-bearing `master_section`.
  Current validated row count: **773,613**.
- **Supply keyword list** `scripts/sql/lookups/supply_keywords.tsv`: **97 include + 26 exclude**
  across 6 categories (art_drafting 32, health_nursing_music_pe 18, math_tech_clickers 6,
  paper_office_general 14, science_lab 15, `placeholder_no_material` 12).

### B. Analysis deliverables
- **Set A / Set B subsets** — Metabase cards **126 / 127**; Parquet hand-off via
  `scripts/export_fall2025_subsets.sh` for reproducible release artifacts.
- **5 tallies** by control × level × set — cards **128–132** (counts, fill-potential,
  distribution, cost, OER/IA coverage).
- **Enrollment assignment** — per-section card **133** + summary card **134**.
- **Master ISBN review extract** (#37) — card **157**: 348,826 raw Fall-2025 groups at
  (ISBN13, Title, Author, Format, FormatType), including broad catalog/DQ populations, with
  NumReq/NumOpt/NumRec/NumBlnk/NumBVAReq/NumTot + IsSupply. Canonical release Model **171** is a
  separate term×ISBN rollup from `material_costs` with 335,157 Fall-2025 records.
- **Top-125 ISBN cost extract** (#33) — card **125**: per-adoption pricing for the 125 most-common
  ISBNs, for same-item analysis.
- **Cost hypothesis test** — card **160** (enrollment-weighted cost) + card **161** (same-item
  demeaned price). Existing verdict: hypothesis supported, mechanism is course-mix not price;
  refresh the cards against the current material-bearing population before using the dollar values.

### C. Metabase self-serve (#39, config-as-code)
- **Models** (GUI notebook-browsable, no SQL): **Master Section** (158), **Master Section — US
  Intro/Intermediate, Fall 2025** (159, the #38 scope), **Master Institution** (170), and
  **Master ISBN** (171). `sync.py` gained model support.
- **3 themed dashboards:** **BMG · Fall 2025 Overview** (18), **BMG · Cost Hypothesis** (16),
  **BMG · Enrollment Data Quality** (17).
- DB id **2**, collection **7** (BMG). Broader catalog: 61 questions + 13 dashboards + 4 models,
  including the Data Quality (Catalog/Pricing), Data Lineage (per-stage), OER/IA Adoption, and the
  parameterized Course Materials Report dashboards.

### D. Documentation & exports
- **Docs:** `SCHEMA.md`, `schema.dbml`, `HANDOFF.md`, `README.md`, this doc; the living Notion
  page (Steps 1–8) + its "Supply keyword lists (#36)" sub-page.
- **Exports (gitignored `output/`):** `export_fall2025_subsets.sh` → Set A/B Parquet;
  `classify_supplies.sh` → supply-ISBN Parquet + prevalence/impact.
- **Rebuild scripts (`.temp/`):** `rebuild_enrichment.sh` (#32/#36), `rebuild_40.sh` (#40),
  `rebuild_3441.sh` (#34+#41) — each a documented stop-Metabase → run → restart → sync ceremony.

### E. Issues / board (GitHub Project "CommodoreSQL Roadmap")
- **Done:** the BMG push **#32, #34, #35, #36, #37, #38, #39, #40, #41**, the canonical
  population/presentation work (**#58, #61**), plus the earlier data-model/viz/filter/DQ
  work (#1–#18, #22, #24, #25, #27, #28, #29, #31, #33).
- **Review:** the whiteboard-aligned Master Section/material-cost release contract (**#59, #63**)
  is implemented and self-validated on PR #62; human review owns Review → Done.
- **Open / Todo:** #19 (persistent DQ logging), #21 (pricing section_id normalization), #23
  (contemporaneous Amazon prices — wishlist), #26 (owned-cost coverage labeling — needs PI
  decision), #30 (Metabase collection reorg), and external-input follow-through tracked in #51/#60.

---

## 3. Points of note & review

**Read before consuming any number.**

- **`price_avg` / `*_cost_avg` = `(min+max)/2`, NOT an arithmetic mean** — legacy convention.
  Label wherever surfaced; the enrollment-weighted cost is a mean *of that summary*.
- **Current material-bearing BMG scope enrollment:** assigned enrollment is **29,040,503**;
  **29.22% of assigned enrollment** derives from imputed section values, **33.30% of sections**
  are imputed, and **23.27%** use the `class_median` rung. Gate/segment any enrollment-weighted
  result on `enrollment_source`. The earlier full-spine values (raw 52.8M →
  assigned 74.0M; 28.6% imputed; own=1,825,095) are historical.
- **The +31% Public-2yr cost gap is course-mix, not price discrimination** — the same-item premium
  is only ~$2. The policy lever is adoption/OER, not bookstore pricing.
- **Supply recall is keyword-bounded** — the classifier misses un-keyworded supplies by design
  (precision ~0.98, recall not exhaustive).
- **The #41 residual (431,363 pseudo-SKU required rows) is expected and legitimate** — the floor of
  real access-code materials (non-978/979 internal SKUs), not a remaining DQ gap. A console DQ line
  tracks it each run.
- **#40 was pre-existing**, exposed (not caused) by #36. The following full-spine scope totals are
  historical reconciliation values, not the current Master Section denominator.
- **Set A/B magnitudes evolved historically** (full-spine total 2,653,161): pre-#36
  2,525,891/127,270 → post-#36 2,521,847/131,314 → post-#40 2,521,855/131,306 → post-#41
  2,520,108/133,053 → post-#58 canonical Use 858,147/1,795,014. The current material-bearing
  BMG scope is **984,588** sections: **858,147 Set A** and **126,441 optional-only Set B**.
- **The earlier merged-model stage reported nine reconciliation checks** (seven `master_section`,
  two `master_course`), including full-spine Use/NoUse and Canada invariants. Those checks and
  their full-spine denominator are historical; current validation follows the material-cost
  section key and cost/release reconciliations.

**Data gotchas (bite people):**
- Blank source `ISBN13` cells import as NULL in the numeric column (~54% of catalog; zero
  empty strings in the current database). Canada = `state='CAN'`
  (single code, blank institution; IPEDS is US-only) — "US only" excludes both `'CAN'` and blank.
- `seats_taken=9999` is an invalid sentinel (excluded from the own_seats rung); pricing sentinels
  ≥9999 are nulled in `pricing_wide` (#27).
- `master_section` is a materialized **TABLE** (current overall population: **6,983,049**;
  cheap `SELECT *`, expensive to rebuild); an un-materialized-view heavy scan has crashed the
  host — bound memory on big ad-hoc scans. Its section population is material-cost-derived;
  `section_enrollment` remains the broader enrollment spine.

**Operational gotchas:**
- Writes require **stopping Metabase** (it holds the DuckDB file lock), then restart + schema
  re-sync via the API.
- **DuckDB v1.1.3 blocks a structural `ALTER`** (RENAME/DROP COLUMN) on a table with any index —
  the #34 rename had to drop/recreate the 3 pricing indexes + `pricing_wide_filtered` view around
  it; #40 used `ADD COLUMN IF NOT EXISTS` + reset instead of DROP.

**Open questions for the reviewer:**
- **#26** — should "owned cost" cover all required materials or only the buy-priced subset, and how
  to label total-vs-owned so they aren't read as an ordered pair? (Needs a PI decision.)
- **#41 audit follow-through** — the legitimate access-code residual is documented; no action
  needed unless a finer access-code vs supply split is later wanted.
- The project Review column remains the human gate; the BMG initial-analysis items have passed it
  and are marked Done.
