# BMG Fall 2025 Cost Analysis — Decisions, Outputs & Review Notes

> 🔗 **In Notion (this doc mirrors that page):** https://app.notion.com/p/396d9fdd1a1a8183a35deb3117511e51

Reference summary of the Bay View Analytics (Jeff Seaman) grant course-materials cost
analysis. Organized by **decisions**, **outputs** (grouped conceptually), and **points of
note & review**. For the chronological build log see the Notion page *"26.06.26 · Fall 2025
Subsets A/B (BMG)"*; for the data model see `SCHEMA.md` / `schema.dbml`; for pickup see
`HANDOFF.md`. As of **2026-08-27**.

## TL;DR

- **Scope:** Fall 2025 (`period_sortable='2025-4'`), 4 undergrad course levels × the 6 real
  IPEDS teaching sectors. Under the #58 canonical Use contract, **Set A** (≥1 required Use
  material) = **858,147** sections and **Set B** (none) = **1,795,014**; total **2,653,161**
  (the complete section spine is conserved).
- **Headline finding:** Public 2-year students face **~$149/student** in required materials vs
  **~$114** for Public 4-year (**+31%**) — but the gap is **course-mix** (which/how many books
  are assigned), **not** paying more for the identical book (same-item premium is only ~$2).
- **Status:** the BMG initial-analysis backlog (#32, #34–#41) is complete and marked **Done**
  on the project board. No held decisions remain.

---

## 1. Decisions

### Scope & subset definition (#35)
- **"Required code" = `is_required_inferred`** (issue #1's inferred-required; renamed from
  `filter_include`, #34). Set A = `required_count > 0`, Set B = `required_count = 0`, where
  `required_count = COUNT(*) FILTER (WHERE is_required_inferred AND is_course_material_use)`.
  The #58 Use flag additionally excludes Canada, missing ISBN, `no_details`, and `no_materials`;
  exclusion-reason booleans remain independently auditable on the retained section spine.
- **Sector = a whitelist of the 6 real teaching sectors** (not Jeff's exclude list). Equivalent
  to "exclude Jeff's list," and additionally drops 128,780 blank/unmatched-sector sections (no
  IPEDS match) and IPEDS sector 0 (Administrative Unit) — neither is a teaching institution.
- **Class cut = `control` × `level` (2yr/4yr)**, not `institution_type` (which carries source
  typos "Priavte"/"Profit"). The 6-way `sector` is available where a finer cut is wanted.
- **Set B includes no-adoption sections** (a section with no book entered has 0 required items) —
  literal to "no item required," flagged for tallies as distinct from optional-only sections.

### Supply classification (#36) & the #41 fold-in
- **Title-keyword classifier, not FormatType** — `FormatType` (Book/eBook/Bundle/…, ~54% blank)
  does not encode supplies, so an **include-AND-NOT-exclude** title-keyword classifier is used.
- **Precision over recall (~0.98)** — a false positive would drop a real textbook, so broad
  keywords are kept with explicit *exclude* overrides (e.g. `calculator` kept, not dropped)
  rather than removed. Recall is intentionally keyword-bounded.
- **Classify once over all 2024+ title variants** of an ISBN (not per-analysis-window), so the
  flag is stable and reusable across periods.
- **In-place exclusion, not parallel columns** — `master_section` counts/costs exclude supplies
  directly; `is_supply` (BOOL_OR) + `supply_count` are kept as audit columns. `section_cost` and
  `master_course_material` exclude them too for cross-view consistency.
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
- **Medians per period over the *scope reference population*** (4 course levels × 6 teaching
  sectors), so Fall-2025 in-scope rows reproduce the reviewed cards 133/134 exactly.
- **Medians, not means** (resist the right-skew of the enrollment distribution); raw `enrollments`
  is never overwritten.

### `has_required` correctness (#40)
- **`has_required` made supply-aware:** `BOOL_OR(book_status='required' AND NOT is_supply)`, so a
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
  the `MATERIALIZED` 4× recompute, the `master_course_material` inconsistency, and #40 itself.
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
- **`master_section`** gained `is_supply` (BOOL_OR) + `supply_count` (#36), and
  `enrollment_assigned` + `enrollment_source` (#32); all material counts/costs
  (`material_count`, `required_count`, `optional_count`, OER/IA, coverage, publishers, and the
  `section_cost`-joined cost columns) now use the canonical #58 Use population while the complete
  section/enrollment spine remains.
- **`section_cost`** and **`master_course_material`** use the canonical #58 Use population.
- **`master_section_us_intro_fall2025`** view (#38): Fall 2025, US-only, intro/intermediate,
  `required_count>=1` — a pure filtered projection of `master_section` (**773,613 rows**).
- **Supply keyword list** `scripts/sql/lookups/supply_keywords.tsv`: **97 include + 26 exclude**
  across 6 categories (art_drafting 32, health_nursing_music_pe 18, math_tech_clickers 6,
  paper_office_general 14, science_lab 15, `placeholder_no_material` 12).

### B. Analysis deliverables
- **Set A / Set B subsets** — Metabase cards **126 / 127**; Parquet hand-off via
  `scripts/export_fall2025_subsets.sh` (Set B now exceeds Metabase's ~1M download cap).
- **5 tallies** by control × level × set — cards **128–132** (counts, fill-potential,
  distribution, cost, OER/IA coverage).
- **Enrollment assignment** — per-section card **133** + summary card **134**.
- **Master ISBN dataset** (#37) — card **157**: one row per (ISBN13, Title, Author, Format,
  FormatType) with NumReq/NumOpt/NumRec/NumBlnk/NumBVAReq/NumTot + IsSupply (~348,826 records).
- **Top-125 ISBN cost extract** (#33) — card **125**: per-adoption pricing for the 125 most-common
  ISBNs, for same-item analysis.
- **Cost hypothesis test** — card **160** (enrollment-weighted cost) + card **161** (same-item
  demeaned price). **Verdict: hypothesis supported, mechanism is course-mix not price** (see TL;DR).

### C. Metabase self-serve (#39, config-as-code)
- **Models** (GUI notebook-browsable, no SQL): **Master Section** (158) and **Master Section — US
  Intro/Intermediate, Fall 2025** (159, the #38 scope). `sync.py` gained model support.
- **3 themed dashboards:** **BMG · Fall 2025 Overview** (18), **BMG · Cost Hypothesis** (16),
  **BMG · Enrollment Data Quality** (17).
- DB id **2**, collection **7** (BMG). Broader catalog: 54 questions + 13 dashboards + 2 models,
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
- **Done:** the BMG push **#32, #34, #35, #36, #37, #38, #39, #40, #41** plus
  the earlier data-model/viz/filter/DQ work (#1–#18, #22, #24, #25, #27, #28, #29, #31, #33).
- **Open / Todo (not started):** #19 (persistent DQ logging), #21
  (pricing section_id normalization), #23 (contemporaneous Amazon prices — wishlist), #26
  (owned-cost coverage labeling — needs PI decision), #30 (Metabase collection reorg), and #61
  (migrate legacy Metabase material predicates to the canonical #58 population).

---

## 3. Points of note & review

**Read before consuming any number.**

- **`price_avg` / `*_cost_avg` = `(min+max)/2`, NOT an arithmetic mean** — legacy convention.
  Label wherever surfaced; the enrollment-weighted cost is a mean *of that summary*.
- **28.6% of scope enrollment is imputed** (raw 52.8M → assigned 74.0M; own=1,825,095). Gate/
  segment any enrollment-weighted result on `enrollment_source`; the class-median rung (~22% of
  sections) is the weakest.
- **The +31% Public-2yr cost gap is course-mix, not price discrimination** — the same-item premium
  is only ~$2. The policy lever is adoption/OER, not bookstore pricing.
- **Supply recall is keyword-bounded** — the classifier misses un-keyworded supplies by design
  (precision ~0.98, recall not exhaustive).
- **The #41 residual (431,363 pseudo-SKU required rows) is expected and legitimate** — the floor of
  real access-code materials (non-978/979 internal SKUs), not a remaining DQ gap. A console DQ line
  tracks it each run.
- **#40 was pre-existing**, exposed (not caused) by #36; total scope stayed conserved throughout.
- **Set A/B magnitudes evolved** (a reconciliation aid — total always 2,653,161):
  pre-#36 2,525,891/127,270 → post-#36 2,521,847/131,314 → post-#40 2,521,855/131,306 → post-#41
  2,520,108/133,053 → post-#58 canonical Use **858,147/1,795,014**.
- **The merged-model stage reports nine reconciliation checks** (seven `master_section`, two
  `master_course`), including the #58 Use/NoUse and Canada invariants; observed post-#58 results
  are recorded after the persistent rebuild.

**Data gotchas (bite people):**
- Blank source `ISBN13` cells import as NULL in the numeric column (~54% of catalog; zero
  empty strings in the current database). Canada = `state='CAN'`
  (single code, blank institution; IPEDS is US-only) — "US only" excludes both `'CAN'` and blank.
- `seats_taken=9999` is an invalid sentinel (excluded from the own_seats rung); pricing sentinels
  ≥9999 are nulled in `pricing_wide` (#27).
- `master_section` is a materialized **TABLE** (cheap `SELECT *`, expensive to rebuild); an
  un-materialized-view heavy scan has crashed the host — bound memory on big ad-hoc scans.

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
