---
notion-id: 3cbd9fdd-1a1a-8086-b499-daa92a739c9f
notion-url: https://app.notion.com/p/sqrlly/Data-Lineage-3cbd9fdd1a1a8086b499daa92a739c9f
notion-sync: push
---

# CommodoreSQL Database Schema

DuckDB pipeline integrating course-catalog data (~103M rows) with institutional
characteristics (IPEDS), bookstore pricing, and opt-out/panel lists. Supports targeted
mailing lists and analysis of course-materials cost and OER/Inclusive-Access adoption.

For the authoritative full relation and column dictionary see
[`DATA-DICTIONARY.md`](DATA-DICTIONARY.md), generated from [`schema.dbml`](schema.dbml)
(load the DBML in dbdiagram.io).
For naming standards and gotchas see [`CLAUDE.md`](CLAUDE.md). For current work status see
[`HANDOFF.md`](HANDOFF.md).

## Source data

BMG owns course materials and raw pricing/cost observations; BVA owns opt-out and mailing
history; IPEDS owns institution metadata. The target names are established executable
compatibility names rather than source-prefixed names. Derived outputs omit source acronyms.

| Owner | File | Compatibility target | Rows |
|---|---|---|---:|
| BMG | `DiscoveryExtract.*.csv` | `course_catalog_<date>` | ~103M |
| IPEDS | `IPEDS_2024.csv` | `ipeds_data` | ~7K |
| BVA | `OptOut_*.csv` | `opt_out` | variable |
| BVA | `panel_*.csv` | `panel` | variable |
| Internal | `format_type_lookup.tsv` | `format_type_classification` | ~69 |
| Internal | `supply_keywords.tsv` | read by `1a_supply_classification.sql` and `scripts/classify_supplies.sh` | 97 incl + 26 excl |
| BMG | `BookPricing.Historical_*.csv` | `pricing_historical` | snapshot-dependent (~27.3M current rows) |

## Pipeline

Run via `scripts/run_sql.sh`. Three stages, each skippable by flag
(`NO_IMPORT` / `NO_EDA` / `NO_EXPORT`). DROP-before-CREATE; re-runnable. Config in
`scripts/dot.env`; SQL is envsubst-templated (`${CONFIG}`, `${LOOKUP_DIR}`, …).

### IMPORT stage

| SQL file | Creates | Purpose |
|----------|---------|---------|
| `0_setup.sql` | `course_catalog_*`, `ipeds_data`, `opt_out`, `panel`, provisional `comprehensive_data`; writes `output/email_issues.tsv` | Load CSVs, normalize emails, derive composite keys (`period_date` included) |
| `0b_state_region.sql` | `state_region` | State → region lookup |
| `1_bookprices_import.sql` | `pricing_historical` | Stage 3: parse and dedupe BMG bookstore pricing; derive provenance keys/source `required`; create pricing indexes |
| `1a_supply_classification.sql` | `supply_isbn_classification` | ISBN-level supply flag from title keywords (#36); built here so `has_required` (1b_) can be supply-aware (#40) |
| `1b_section_filter.sql` | `section_book_status` | One row per section: supply-aware `has_required` flag (#40); pricing remains untouched |
| `2_oer_classification.sql` | `format_type_classification`, (re)builds `comprehensive_data` | OER/IA lookup, enriched normalized BMG source-row table, and row flags |
| `2b_course_materials.sql` | `section_enrollment`, `course_materials`, four `course_materials_*` views | First canonical processed item table; one section×ISBN row plus one NULL-ISBN audit row per section when present; source/variant/conflict fields and canonical population views |
| `2c_pricing_wide.sql` | **`pricing_wide`** (TABLE) | BMG-owned pivot with provenance, 18 price cols, `has_buy`/`has_rent`, and fact aggregates; no catalog/IPEDS enrichment |
| `2d_data_quality.sql` | `__data_quality_*` tables | Materialized, non-mutating DQ snapshots including exact pricing-to-catalog comparisons |

### EDA stage

| SQL file | Creates | Purpose |
|----------|---------|---------|
| `3_mailing_lists.sql` | **`master_mailing`** (TABLE), `recent_periods`, `current_mailing`, 7 state views | Persisted one-row-per-cleaned-email Master from the normalized course-material import; history/opt-out Working view and exhaustive normalized CA/TX/FL/NY/PA/CAN/Other partitions |
| `3b_material_costs.sql` | **`material_costs`** (TABLE) | Only LEFT pricing enrichment of canonical `course_materials_use`; retains unmatched/unpriced Use items |
| `4_merged_records.sql` | **`section_cost`** (table), **`master_section`** (TABLE), `master_course` (view), `master_course_material` (view), `master_section_us_intro_fall2025` (view) | Material-cost section rollups, material-bearing Master Section, and BMG report view |
| `models/*.sql` | **`master_institution`**, **`master_isbn`**, **`sample10_section_ids`** (TABLEs) | Canonical term rollups and deterministic section-sample membership; `master_isbn` consumes `material_costs`; auto-discovered and materialized by `run_sql.sh` after the EDA SQL files |

### EXPORT stage

Auto-discovers the 24 `scripts/sql/exports/*.sql` files in lexical order; wraps each in a temp
table and `COPY`s it to `output/<SQL basename>.csv`. The exact order, source models, filters, and
file names are inventoried under [Data lineage](#data-lineage). Analysis extracts like the A/B
subsets and supply classification are separate re-runnable scripts —
`scripts/export_fall2025_subsets.sh`, `scripts/classify_supplies.sh` — that write Parquet to
`output/`. `scripts/export_cmm_masters.sh` is also separate from `run_sql.sh`; it writes one
release-dated CSV per material-bearing term from the materialized Material Costs, Master Section,
Master Institution, and Master ISBN tables.
`scripts/export_course_materials.sh` is a separate read-only exporter for the five canonical
Course Materials relations, with optional term filtering.
`38_cmm_release_reconciliation.sql` and `39_cmm_release_key_reconciliation.sql` check the canonical
population, material-cost, section, institution, ISBN, and exact section-key paths by term after
those tables are materialized. They are split to keep the two high-cardinality states sequential.
Per-term exports are direct `period_sortable` filters of Material Costs and the three release
masters; full exports retain `period_sortable` and combine all available terms without changing
the item grain. The material-cost baseline expected for the refreshed snapshot is 12,806,060
rows.

## Key tables

- **`comprehensive_data`** — exactly one enriched, normalized BMG source row (catalog × IPEDS ×
  opt-out × panel lookup × format-type × section status), validated at 102,885,609 rows. It
  remains the source for faculty and raw DQ consumers, and owns row-level population booleans.
- **`panel` / `panel_email`** — raw panel source rows remain retained; `panel_email` is the
  one-row-per-cleaned-email enrichment lookup with the maximum stored response year and
  multiplicity counts, so
  panel history cannot multiply `comprehensive_data` rows.
- **Mailing Master and Working** — materialized `master_mailing` deterministically chooses one row
  per cleaned email directly from the normalized course-material import by newest period, largest
  enrollment, then stable source fields. It does not join history or filter opt-outs.
  `current_mailing` is the whiteboard's Mailing Working view: it uses the newest 12 periods, joins
  `panel_email`, and excludes `opt_out`. `UPPER(TRIM(state))` routes Working into disjoint
  CA/TX/FL/NY/PA/CAN/Other views, with Other retaining NULL, blank, and unknown states. The updated
  history source itself remains pending in #56. See the complete
  [mailing lineage](#mailing-source-master-working-and-export-lineage) and the canonical
  [step-by-step contract](CMM-ETL.md#mailing-source-master-and-working-contract-66).
- **`course_materials`** — first canonical processed table, one row per
  `(period_sortable, section_id, isbn13)` plus one NULL-ISBN audit row per section when present.
  It carries representative catalog metadata, source counts, variant/conflict evidence, flags,
  and assigned enrollment, validated at 96,663,781 rows. The four
  `course_materials_*` views are direct canonical projections.
- **`pricing_historical`** — indexed, deduplicated source-owned pricing at the source logical
  grain; no catalog classification is written back after import.
- **`pricing_wide`** — one row per `(section_id, isbn13)`: source/provenance fields, 18 price
  columns (option × condition × format), `has_buy`/`has_rent`, `price_min/max`, `price_avg DOUBLE`,
  `rental_days_min/max`, and `format_count`. It has no required-inference, OER/IA, or IPEDS fields
  and no required-only companion view. Exact-join evidence and future proposals live only in the
  [issue #21 limitation](CMM-ETL.md#current-limitation--pricing-to-catalog-section-matching-issue-21).
- **`section_enrollment`** — exact one row per `(period_sortable, section_id)` with authoritative
  raw enrollment/flags, section-scope dimensions, assigned enrollment, and `enrollment_source`.
  Built in stage 2b, it owns the complete valid 2024+ section population; `course_materials`,
  `material_costs`, and `master_section` consume it so raw inputs, flags, and assignment agree.
- **`material_costs`** — materialized one row per `(period_sortable, section_id, isbn13)`
  canonical Use item. It retains items without a pricing row or valid price and uses catalog-owned title/author/publisher,
  format, FormatType, status, and flags from `course_materials`; a LEFT join to `pricing_wide`
  contributes bookstore URL, all 18 price cells, `format_count`, price bounds, rental range,
  and buy bounds. Term/ISBN compatibility metadata needed by `master_isbn` is also persisted here,
  so that rollup does not return to raw catalog rows. Expected current baseline: 12,806,060 rows.
- **`section_cost`** — per-material-bearing-section required/optional cost aggregates consumed
  from `material_costs`. A section can have Use materials but no valid price, producing NULL cost
  bounds. It is not the approved item-level input.
- **`master_section`** — **materialized TABLE**, one row per distinct
  `(period_sortable, section_id)` represented in canonical `material_costs` (6,983,049 current
  rows). Material/required/optional counts, OER/IA, publishers, ISBN/FormatType, and coverage
  derive from deduplicated `material_costs`; price/cost fields join from `section_cost`; section
  dimensions, enrollment flags, and exact assigned enrollment join from `section_enrollment`.
  Compact NoUse/placeholder/Canada/supply fields are sidecar audits over canonical `course_materials`
  rows for retained material-bearing sections only—not full-population denominators. Complete valid section and
  enrollment coverage remains upstream in `section_enrollment`.
- **`master_course`** — view: one row per `(course_id, period)`, rollups of the above.
- **`master_institution`** — table: one row per `(period_sortable, unit_id)` represented by a
  material-bearing Master Section row, including an explicit NULL-unit unknown bucket when one is
  present; institution attributes, deterministic bookstore URL from all same-term `pricing_wide`
  rows, and material-section coverage/totals (#54).
- **`master_isbn`** — table: one row per `(period_sortable, isbn13)` for canonical Use
  materials consumed from `material_costs`; canonical metadata with conflict DQ, section-level
  coverage, all 18 price-cell counts, enrollment, and institution-type counts (#55).
- **`sample10_section_ids`** — table: one row per selected section, using the version-stable
  `md5-prefix64-mod10-v1` bucket-zero rule. All sampled stages join this one membership table (#53).
- **`master_section_us_intro_fall2025`** — view (BMG #38): filtered projection of `master_section`
  (Fall 2025, `required_count>=1`, intro/intermediate course levels, and
  `state NOT IN ('CAN','')`; NULL state is also excluded). The relation name is retained for
  compatibility, but the executable geography rule is a non-Canada/nonblank-state proxy rather
  than validated institution-country membership. No new columns.

## Data lineage

This section is the canonical **implemented execution and file-output map**. The source-faithful
whiteboard transcription remains in
[`comms/media/2026-08-17-data-flow.md`](comms/media/2026-08-17-data-flow.md); proposed sources from
that board are not drawn as though they execute today. SQL remains authoritative for field
semantics. Detailed selection rules, derived fields, denominators, and NULL meanings are in
[`CMM-ETL.md`](CMM-ETL.md#4-selection-inclusion-and-exclusion-rules),
the authoritative [`DATA-DICTIONARY.md`](DATA-DICTIONARY.md), generated from
[`schema.dbml`](schema.dbml). Its embedded detailed Master Section appendix carries the extended
business, NULL, and denominator contract without duplicating it here.

The detailed ETL contract is also synced as this Notion child page:

<page url="https://app.notion.com/p/CMM-ETL-Contract-3cbd9fdd1a1a81d893effd579a76812b">CMM ETL Contract</page>

### Exact `run_sql.sh` execution order

Arrows in this first diagram mean **execution order**, not table dependency. A skipped stage
removes its whole subgraph (`NO_IMPORT`, `NO_EDA`, or `NO_EXPORT`). Model and export files are
discovered with a lexical sort; the ordering shown below is therefore executable behavior.

```mermaid
flowchart TD
    run["scripts/run_sql.sh"] --> i00
    run -. "NO_IMPORT" .-> e30
    run -. "NO_IMPORT + NO_EDA" .-> x01

    subgraph import["IMPORT — unless NO_IMPORT"]
        i00["01 · 0_setup.sql"] --> i0b["02 · 0b_state_region.sql"]
        i0b --> i10["03 · 1_bookprices_import.sql"]
        i10 --> i1a["04 · 1a_supply_classification.sql"]
        i1a --> i1b["05 · 1b_section_filter.sql"]
        i1b --> i20["06 · 2_oer_classification.sql"]
        i20 --> i2b["07 · 2b_course_materials.sql"]
        i2b --> i2c["08 · 2c_pricing_wide.sql"]
        i2c --> i2d["09 · 2d_data_quality.sql"]
    end

    i2d --> e30
    i2d -. "NO_EDA" .-> x01
    subgraph eda["EDA + models — unless NO_EDA"]
        e30["10 · 3_mailing_lists.sql"] --> e3b["11 · 3b_material_costs.sql"]
        e3b --> e40["12 · 4_merged_records.sql"]
        e40 --> m01["13 · models/master_institution.sql"]
        m01 --> m02["14 · models/master_isbn.sql"]
        m02 --> m03["15 · models/sample10_section_ids.sql"]
    end

    m03 --> x01
    subgraph exports["EXPORT — unless NO_EXPORT; each node becomes output/{basename}.csv"]
        x01["01_sample_records.sql"] --> x10["10_master_mailing.sql"]
        x10 --> x11c["11_current_mailing.sql"]
        x11c --> x11r["11_recent_mailing.sql"]
        x11r --> x20["20_california_mailing.sql"]
        x20 --> x21["21_texas_mailing.sql"]
        x21 --> x22["22_florida_mailing.sql"]
        x22 --> x23["23_newyork_mailing.sql"]
        x23 --> x24["24_texas_fall_series.sql"]
        x24 --> x25["25_pennsylvania_mailing.sql"]
        x25 --> x26["26_canada_mailing.sql"]
        x26 --> x27["27_other_mailing.sql"]
        x27 --> x30["30_faculty_records.sql"]
        x30 --> x31["31_master_section.sql"]
        x31 --> x32["32_master_course.sql"]
        x32 --> x33["33_master_course_material.sql"]
        x33 --> x34["34_master_section_sample10pct.sql"]
        x34 --> x35["35_master_institution_by_term.sql"]
        x35 --> x36["36_master_isbn_by_term.sql"]
        x36 --> x37["37_sample10_reconciliation.sql"]
        x37 --> x38["38_cmm_release_reconciliation.sql"]
        x38 --> x39["39_cmm_release_key_reconciliation.sql"]
        x39 --> x40["40_material_costs_by_term.sql"]
        x40 --> x41["41_material_costs_reconciliation.sql"]
    end
```

If `NO_IMPORT` is set, execution begins at `3_mailing_lists.sql`; if `NO_EDA` is also set, it
begins at the export list. `CUSTOM_SQL_FILES` replaces the assembled list entirely, so a custom
run is intentionally outside the fixed order above.

### Implemented table and file lineage

Solid arrows in the following build diagrams mean **data dependency**. Labels call out the
population or grain transition where it matters. Dotted arrows identify logical subset/reference
relationships when the downstream SQL reads the owning table/flag rather than the displayed view.
Standalone exporters appear in the separate export diagram.

#### Import and enrichment dependencies

```mermaid
flowchart TD
    catalog_csv["BMG DiscoveryExtract CSV"] --> catalog["course_catalog_<date><br/>compatibility name; source-row grain"]
    ipeds_csv["IPEDS CSV"] --> ipeds["ipeds_data<br/>one institution"]
    optout_csv["BVA OptOut CSV"] --> optout["opt_out<br/>compatibility name; cleaned email rows"]
    panel_csv["BVA panel/history CSV"] --> panel["panel<br/>compatibility name; cleaned email rows"]
    panel --> panel_email["panel_email<br/>one row per email<br/>MAX response year + multiplicity counts"]
    pricing_csv["BMG BookPricing CSV"] --> pricing["pricing_historical<br/>compatibility name; section × ISBN × option × condition × format × rental days<br/>latest logical-key snapshot"]
    format_tsv["format_type_lookup.tsv"] --> ftc["format_type_classification"]
    supply_tsv["supply_keywords.tsv"] --> supply["supply_isbn_classification<br/>2024+ ISBN title variants"]
    static_region["static state/region SQL values"] --> region["state_region<br/>one state/province code"]
    catalog_csv --> email_audit["output/email_issues.tsv"]
    catalog --> cd0["provisional comprehensive_data<br/>0_setup.sql; replaced at step 6"]
    ipeds --> cd0
    optout --> cd0
    panel_email --> cd0
    cd0 --> region_check["state_region coverage console check"]
    region --> region_check
    catalog --> supply
    catalog --> sbs["section_book_status<br/>one section; supply-aware has_required"]
    supply --> sbs
    catalog --> cd["comprehensive_data<br/>catalog/adoption-row grain"]
    ipeds --> cd
    optout --> cd
    panel_email --> cd
    ftc --> cd
    supply --> cd
    sbs --> cd

    cd --> cm["course_materials<br/>one period × section × ISBN<br/>+ one NULL-ISBN audit row/section"]
    cm --> post24["course_materials_post_2024<br/>WHERE is_post_2024"]
    cm --> use["course_materials_use<br/>post-2024 + non-Canada + ISBN + non-supply<br/>+ not no-details/no-materials"]
    cm --> nouse["course_materials_no_use<br/>exact post-2024 complement of Use"]
    cm --> canada["course_materials_canada<br/>post-2024 AND state = CAN"]
    canada -. "subset" .-> nouse
    pricing --> pw["pricing_wide<br/>one section × ISBN; 18 price cells"]
    cd --> dq["__data_quality_* snapshot tables"]
    pricing_csv --> dq
    pricing -->|"exact, non-mutating comparison"| dq
    pw --> dq
```

The final `comprehensive_data`, `panel_email`, `course_materials`, `section_enrollment`,
`pricing_wide`, and `section_book_status` nodes repeat below as connectors into EDA; they are not
rebuilt between diagrams.

#### EDA and model dependencies

```mermaid
flowchart TD
    catalog["course_catalog_YYYYMMDD<br/>normalized imported course-material rows"]
    cd["comprehensive_data<br/>catalog/adoption-row grain"]
    pw["pricing_wide<br/>one section × ISBN"]
    sbs["section_book_status<br/>one section"]
    cm["course_materials<br/>one period × section × ISBN<br/>canonical processed items"]
    use["course_materials_use view<br/>canonical Use projection"]

    catalog --> mailing_branch["mailing branch<br/>source → Master → Working → exports<br/>detailed below"]
    cd --> se["section_enrollment<br/>one period × section; 2024+ non-null section/term spine"]
    cd -->|"canonicalize source rows"| cm
    cm --> use
    use -->|"only LEFT pricing enrichment"| costs["material_costs<br/>one period × section × ISBN"]
    se -->|"assigned enrollment + section fields"| cm
    se -->|"section dimensions + enrollment"| costs
    pw -->|"LEFT JOIN on exact section × ISBN; retain unpriced Use items<br/>see CMM-ETL issue #21 limitation"| costs

    costs --> sc["section_cost<br/>one material-bearing period × section"]
    costs --> ms["master_section<br/>one material-bearing period × section"]
    se -->|"section dimensions + enrollment"| ms
    sc -->|"required/optional price rollups"| ms
    cm -->|"retained-section excluded-item sidecar audit"| ms

    ms --> mc["master_course<br/>one course × period"]
    sc --> mc
    costs --> mcm["master_course_material<br/>course × period × publisher × status"]
    ms --> usv["master_section_us_intro_fall2025"]
    ms --> mi["master_institution<br/>one period × institution"]
    sbs --> mi
    pw -->|"same-term bookstore URL exception"| mi
    costs --> misbn["master_isbn<br/>one period × ISBN"]
    se --> sample10["sample10_section_ids<br/>MD5 bucket 0 over full section spine"]

```

`state_region` is built in execution step 2 and is joined at query time by the Metabase report
questions; it does not enrich `comprehensive_data` or a materialized release table. The import step
also writes `output/email_issues.tsv` directly from the raw catalog CSV.

#### Mailing source, Master, Working, and export lineage

This diagram is the complete implemented mailing branch. Node subtitles state the grain or filter;
the canonical prose contract and the resolved difference from the historical workflow attachment
are centralized in
[`CMM-ETL.md`](CMM-ETL.md#mailing-source-master-and-working-contract-66).

```mermaid
flowchart TD
    catalog_csv["BMG DiscoveryExtract CSV<br/>raw catalog/source rows"]
    catalog["course_catalog_&lt;date&gt;<br/>normalized source-row table"]
    panel_csv["existing BVA panel/history CSV"]
    panel["panel<br/>lower/trim email; source rows retained"]
    panel_email["panel_email<br/>one row/email; MAX response year + multiplicity"]
    optout_csv["BVA OptOut CSV"]
    opt_out["opt_out<br/>lower/trim email; source rows retained"]
    master["master_mailing TABLE<br/>one row/nonblank cleaned email<br/>newest term → enrollment → stable tie-breaks<br/>no history join or opt-out filter"]
    recent["recent_periods VIEW<br/>newest 12 non-NULL terms represented in Master"]
    working["current_mailing VIEW / Mailing Working<br/>latest-12 + history-enriched + opt-out-excluded<br/>one eligible row/email"]

    catalog_csv -->|"0_setup: extract/first address;<br/>remove spaces; lower + trim"| catalog
    panel_csv -->|"0_setup: lower + trim"| panel
    panel -->|"GROUP BY email"| panel_email
    optout_csv -->|"0_setup: lower + trim"| opt_out
    catalog -->|"non-NULL/nonblank email;<br/>GROUP BY cleaned email"| master
    master -->|"DISTINCT term; DESC; LIMIT 12"| recent
    master --> working
    recent -->|"term IN recent_periods"| working
    panel_email -->|"LEFT JOIN on email;<br/>missing history retained"| working
    opt_out -->|"NOT EXISTS on email"| working

    master --> e10["10_master_mailing.csv<br/>staging/audit; not send-ready"]
    working --> e11c["11_current_mailing.csv<br/>selected Working columns"]
    working --> e11r["11_recent_mailing.csv<br/>all Working columns; same population"]

    working -->|"UPPER(TRIM(state)) = CA"| ca["current_mailing_ca"]
    working -->|"= TX"| tx["current_mailing_tx"]
    working -->|"= FL"| fl["current_mailing_fl"]
    working -->|"= NY"| ny["current_mailing_ny"]
    working -->|"= PA"| pa["current_mailing_pa"]
    working -->|"= CAN"| can["current_mailing_can"]
    working -->|"COALESCE(normalized state, '')<br/>outside named codes"| other["current_mailing_other<br/>NULL / blank / unknown residual"]

    ca --> e20["20_california_mailing.csv"]
    tx --> e21["21_texas_mailing.csv"]
    tx -->|"period LIKE 'Fall%'"| e24["24_texas_fall_series.csv"]
    fl --> e22["22_florida_mailing.csv"]
    ny --> e23["23_newyork_mailing.csv"]
    pa --> e25["25_pennsylvania_mailing.csv"]
    can --> e26["26_canada_mailing.csv"]
    other --> e27["27_other_mailing.csv"]
```

The seven geographic views are pairwise disjoint and collectively exhaustive over Working; the
SQL emits a row/distinct-email reconciliation check after creating them. The original `state` value
is exported even though routing uses its normalized form. `run_sql.sh` also rejects any mailing
wrapper that follows an import in the same invocation without a later mailing refresh; an explicit
`NO_IMPORT=1` wrapper-only run may reuse the last refreshed relations.

### Export lineage

Solid arrows below mean source-to-file dependency. Dotted `next` arrows preserve the normal
24-wrapper lexical execution order; labeled dashed arrows are implemented standalone commands.
Exact wrapper order, row filters, and artifact names follow in the inventory.

```mermaid
flowchart TD
    raw_source["comprehensive_data"] --> raw["01_sample_records.csv"]
    raw -. "next: mailing branch shown above" .-> mail["10, 11, and 20–27 mailing CSVs"]
    mail -. "next" .-> faculty_source["comprehensive_data"]
    faculty_source --> faculty["30_faculty_records.csv"]
    faculty -. "next" .-> model_source["master_section / master_course / master_course_material<br/>+ sample membership / Master Institution / Master ISBN"]
    model_source --> model["31–36 model and sample CSVs"]
    model -. "next" .-> core["catalog + section enrollment + material costs + section cost<br/>+ sample membership + three master tables"]
    core --> checks["37_sample10 / 38_release / 39_key reconciliation CSVs"]
    checks -. "next" .-> costs["material_costs"]
    costs --> costs_export["40_material_costs_by_term.csv"]
    costs_export -. "next" .-> final_source["comprehensive_data + course_materials + material_costs + master_section"]
    final_source --> final_check["41_material_costs_reconciliation.csv<br/>raw → canonical → cost reconciliation"]

    standalone["material_costs + three master tables"] -. "export_cmm_masters.sh" .-> terms["four release-dated CSVs per selected term"]
    canonical["course_materials + four canonical views"] -. "export_course_materials.sh<br/>optional YYYY-N term filter" .-> canonical_files["five dated Course Materials CSVs"]
    standalone2["master_section"] -. "export_fall2025_subsets.sh" .-> ab["Fall 2025 Set A / Set B Parquet"]
    standalone3["comprehensive_data + supply keywords"] -. "classify_supplies.sh" .-> supply["Fall 2025 supply-ISBN Parquet"]
```

### Automatic export inventory

These are the 24 SQL wrappers run by the normal EXPORT stage, in exact lexical execution order.
Each produces `output/<SQL basename>.csv` without changing the listed source grain unless a filter
or aggregation is stated. Mailing Master is selected and persisted once by `3_mailing_lists.sql`;
the Working and geographic wrappers query lightweight views over that table rather than repeating
the raw catalog deduplication.

| Order | SQL wrapper | Source and transformation |
|---:|---|---|
| 1 | `01_sample_records.sql` | 10,000 randomly ordered `comprehensive_data` rows |
| 2 | `10_master_mailing.sql` | selected columns from pre-history/pre-opt-out `master_mailing`; staging/audit output, not a send-ready list |
| 3 | `11_current_mailing.sql` | selected columns from opt-out-filtered `current_mailing` / Mailing Working |
| 4 | `11_recent_mailing.sql` | all columns from opt-out-filtered `current_mailing` / Mailing Working; same row population as export 11, not an independently calculated recency set |
| 5 | `20_california_mailing.sql` | `current_mailing_ca` |
| 6 | `21_texas_mailing.sql` | `current_mailing_tx` |
| 7 | `22_florida_mailing.sql` | `current_mailing_fl` |
| 8 | `23_newyork_mailing.sql` | `current_mailing_ny` |
| 9 | `24_texas_fall_series.sql` | Texas current-mailing rows whose source period starts with `Fall` |
| 10 | `25_pennsylvania_mailing.sql` | `current_mailing_pa` |
| 11 | `26_canada_mailing.sql` | `current_mailing_can` |
| 12 | `27_other_mailing.sql` | complete `current_mailing_other` residual, including NULL/blank/unknown states |
| 13 | `30_faculty_records.sql` | `comprehensive_data` aggregated by faculty identity after requiring instructor, course number, section, and course title |
| 14 | `31_master_section.sql` | full all-term `master_section` |
| 15 | `32_master_course.sql` | full all-term `master_course` |
| 16 | `33_master_course_material.sql` | full all-term `master_course_material` |
| 17 | `34_master_section_sample10pct.sql` | `master_section` intersected with `sample10_section_ids` |
| 18 | `35_master_institution_by_term.sql` | all-term `master_institution`, ordered by term and institution |
| 19 | `36_master_isbn_by_term.sql` | all-term `master_isbn`, ordered by term and ISBN |
| 20 | `37_sample10_reconciliation.sql` | full-versus-deterministic-sample checks across catalog, section, material, cost, and master stages |
| 21 | `38_cmm_release_reconciliation.sql` | exact cross-model measures by term |
| 22 | `39_cmm_release_key_reconciliation.sql` | exact Material Costs/Master Section section-key comparison by term |
| 23 | `40_material_costs_by_term.sql` | full all-term `material_costs`, ordered by term, section, and ISBN |
| 24 | `41_material_costs_reconciliation.sql` | exact Use-key, pricing-match, uniqueness, NULL-key, and Master Section coverage checks |

`01_sample_records.sql` is an unseeded 10,000-row raw diagnostic and is unrelated to the canonical
deterministic section sample used by `sample10_section_ids`, export 34, and export 37.

### Current standalone exporters

These commands are implemented and re-runnable, but **do not run as part of `scripts/run_sql.sh`**.

| Command | Current files |
|---|---|
| `scripts/export_cmm_masters.sh [terms…]` | Four release-dated CSVs per selected material-bearing term under `output/cmm/`: `master_section`, `master_institution`, `master_isbn`, and `material_costs` |
| `scripts/export_course_materials.sh [YYYYMMDD] [YYYY-N]` | Five dated CSVs under `output/course_materials` (or `COURSE_MATERIALS_OUTPUT_DIR`): `course_materials`, `course_materials_post_2024`, `course_materials_use_post_2024`, `course_materials_nouse_post_2024`, and `course_materials_can_post_2024`; the term argument is optional; stages all five and refuses overwrite |
| `scripts/export_fall2025_subsets.sh` | `output/fall2025_setA_required.parquet` and `output/fall2025_setB_no_required.parquet` |
| `scripts/classify_supplies.sh` | `output/fall2025_supply_isbns.parquet`; subsequent statements print classification/cost diagnostics |
| `scripts/export_all.sh` | Alternate CSV runner for the same 24 SQL wrappers under `output/exports/` |
| `scripts/export_all_parquet.sh` | Noncanonical recursive Parquet runner under `output/`: the 24 top-level wrappers plus eight `exports/optional/*.sql` legacy summary queries, with numeric prefixes removed. The optional queries depend on `5_`/`6_` summary views that `run_sql.sh` does not rebuild. |

The five Course Materials exports are standalone only and are not automatic SQL wrappers; they
accept a release date and optional `YYYY-N` term filter. Mailing wrappers 25–27 automatically
export the implemented Pennsylvania, Canada, and complete Other residual partitions. The
history/opt-out source policy remains tracked in issue #56 and is not resolved by this routing.
`scripts/classify_supplies.sh` independently reclassifies Fall 2025 for an audit extract; it is not
the all-2024+ `supply_isbn_classification` table consumed by the canonical pipeline.

### Pending paths, not current execution

The whiteboard's Spring 2026 catalog/pricing, updated IPEDS, external pricing, discipline,
mailing-history, campus IA, and shared 25-institution inputs have no active SQL nodes yet. They are
owned by issues #51, #52, #56, #57, and #60 and stay outside the implemented diagrams until their
files, grains, keys, and semantics are validated. The whiteboard note “Keep History” is likewise not
an implemented cross-snapshot retention layer: `1_bookprices_import.sql` drops/recreates the
source-owned `pricing_historical`, keeps only the latest row at each logical pricing key within the
configured input snapshot, and builds its indexes. Pricing-to-catalog matching remains an exact,
non-mutating DQ comparison; see the issue #21 limitation in `CMM-ETL.md`.

## Key concepts

### Non-Master enrichment NULL semantics

- Nullable IPEDS descriptors mean the source `unit_id` did not match available IPEDS metadata;
  they are not zeroes or a synthetic institution category.
- Nullable panel/opt-out enrichment means no matching cleaned email was present in that BVA
  input. `is_opted_out=FALSE` is the executable default; a NULL panel year means no recorded year.
- Nullable pricing fields after the `material_costs` LEFT join mean either no exact section×ISBN
  pricing match or no supplied/valid value. Use `has_pricing_match` to distinguish those cases;
  NULL price is never zero cost.
- `current_mailing_other` is intentionally the exhaustive residual after normalized CA, TX, FL,
  NY, PA, and CAN routing, including NULL, blank, and unknown state values.

The generated [`DATA-DICTIONARY.md`](DATA-DICTIONARY.md) carries the column-level details. Its
embedded Master Section appendix owns the expanded release-table NULL and denominator contract.

### Composite keys
- `course_id` = `unit_id::dept_code::course_number`
- `section_id` = `unit_id::dept_code::course_number::section::period_sortable` — **includes period**
  (each section-offering is its own ID). `(section_id, isbn13)` is the natural catalog grain.
- `period_sortable` = `YYYY-N` (1=Winter, 2=Spring, 3=Summer, **4=Fall**); `period_date` = canonical
  DATE for time-series axes.

### is_required_inferred (the "required code", issue #1)
Inferred is_required. TRUE when `period_date >= 2024-01-01` AND
`(has_required=TRUE AND book_status='required')` OR `(has_required=FALSE AND book_status IS NULL)`.
Applied to catalog-owned `comprehensive_data`, not to either pricing table.
`master_section.required_count` =
the count of canonical `material_costs` items where `is_required_inferred` is true; membership in
that table already guarantees the Use predicate. (Renamed from `filter_include`, #34.)

`has_required` is **supply-aware** (#40): `BOOL_OR(book_status='required' AND NOT is_supply)`, built in
`1a_`/`1b_`. A supply-only "required" item (e.g. safety goggles) no longer forces `has_required=TRUE`,
so a co-listed blank-status **real** textbook correctly keeps the required fallback instead of being
bucketed as optional. #41 (resolved): pseudo-SKU non-book items are overwhelmingly **legitimate**
required digital-access materials (Cengage/Pearson/MyLab access codes) — kept. Two narrow, precision-
verified gaps were folded into the supply classifier: `eyewear` supplies and explicit "no material
required" placeholder rows (`supply_category='placeholder_no_material'`). A console DQ line tracks the
remaining (legitimate) pseudo-SKU residual.

### OER/IA classification
Explicit lookup via `format_type_classification` (FormatType → `is_oer`/`is_ia` + categories).
NULL when FormatType is absent — so `has_formattype` is the classifiability flag.

### Supply classification (issue #36)
Bookstore **supplies** (lab kits, goggles, calculators, clickers, …) are identified by an
include-AND-NOT-exclude **title-keyword** classifier (`FormatType` does not encode supplies).
Keyword list: `scripts/sql/lookups/supply_keywords.tsv` (97 include + 26 exclude, single source of
truth). `1a_supply_classification.sql` builds `supply_isbn_classification` (ISBN-level, over **all
2024+** title variants) and `2_oer_classification.sql` joins `is_supply`/`supply_category` onto
`comprehensive_data`. When multiple include patterns match, attribution deterministically prefers
specific rules over the generic `>supply<`/`>suppy<` fallbacks, then the longest pattern and stable
lexical tie-breaks at title and ISBN levels. This changes representative attribution only, not
which ISBNs qualify or their Use/NoUse membership. Supplies are NoUse for every material/count/cost aggregate, while
`master_section` surfaces `is_supply` (`BOOL_OR`) + `supply_count` only for excluded source rows
that co-occur with a retained material-bearing section. Complete supply audits use
`comprehensive_data`.
Precision-over-recall (≈0.98); recall
is keyword-bounded. The `placeholder_no_material` category (#41) reuses this mechanism to exclude
explicit "no material required" placeholder rows. Supplies are <1% of Fall-2025 ISBNs — excluding them
barely moves class medians but removes the high-price tail.

### Course-material population contract (issue #58)

`comprehensive_data` owns non-null row booleans at enriched source-row grain. `is_post_2024` means
`period_date >= DATE '2024-01-01'`; `has_isbn` is `ISBN13 IS NOT NULL` (the imported
numeric column maps blank source cells to NULL while retaining nonstandard numeric pseudo-SKUs);
`has_formattype` means nonblank `FormatType`; enrollment flags test non-null enrollment and
non-null `seats_taken < 9999`; `no_details` is the exact title `*No Book Details*`;
`no_materials` is the exact title `*No Books Required*` or
`supply_category='placeholder_no_material'`; and `is_canada` is `state='CAN'`.

Use is post-2024, non-Canadian, ISBN-bearing, non-supply, and neither placeholder flag. NoUse is
its exact post-2024 complement; both are false pre-2024, and Canada is a NoUse subset. No single
exclusion-reason field is stored because the reason booleans can overlap. Non-978/979 pseudo-SKUs
remain eligible unless the existing supply classifier catches them (#41).

The `course_materials` row population is the first canonical item set: one row per valid
period/section/ISBN and one NULL-ISBN audit row per section when present. `material_costs` is the
distinct canonical Use/material key set, one row per period-specific section/ISBN. `master_course` and `master_institution`
roll up that same material-bearing population. No-ISBN, no-adoption, NoUse-only, Canada-only, and
supply-only sections remain available in `comprehensive_data` and the complete
`section_enrollment` spine; they do not create release-facing Master Section rows. Sidecar audit
columns on retained rows describe excluded source records that co-occur with an included material
section and must not be interpreted as complete-population counts.

The authoritative full relation/column inventory is [`DATA-DICTIONARY.md`](DATA-DICTIONARY.md).
Its embedded [`MASTER-SECTION-DICTIONARY.md`](MASTER-SECTION-DICTIONARY.md) appendix supplies every
exported Master Section business label, owning source/aggregation, denominator, and NULL meaning.

### Canonical material-cost spine

`material_costs` is the approved item-level input: one material row per
`(period_sortable, section_id, isbn13)` after the `course_materials_use` projection. Catalog
duplicates at that key collapse in `course_materials` before enrichment; source disagreement is
retained as explicit variant/conflict signals (for example title, author, publisher, format, or
FormatType variant counts) rather than silently choosing a pricing value. A LEFT join to the
one-row-per-key `pricing_wide` table preserves every Use item.
`section_cost` aggregates this table; `master_section` is its one-row-per-section rollup; and
`master_isbn` rolls it up by term and ISBN. Source-owned `pricing_historical` and `pricing_wide`
remain available for pricing-only analysis and DQ, but never own catalog attributes.

The current expected baseline is 12,806,060 material-cost rows. This baseline is not a claim that
Spring 2026 or any external source has landed locally.

### Enrollment fill (issue #32)
`section_enrollment` owns the persisted per-section enrollment, filling missing values by a
documented hierarchy; `enrollment_source` records the rung used:
`own → own_seats (<9999) → sibling_enroll → sibling_seats → class_median (control×level) →
level_median`. Medians are computed **per period** over the **reference population** (the 4 BMG
course levels × 6 real teaching sectors), so Fall-2025 in-scope rows reproduce the reviewed
analysis (cards 133/134) exactly. Raw `enrollments` is never overwritten; `enrollment_source='none'`
(NULL value) only for rows with no reachable signal.

### Pricing — rental term collapsing
`pricing_historical` grain: `(section_id, isbn13, book_option, book_condition, book_format,
rental_days)`. Buy = one price per (condition × format); rental = one price per `rental_days`
(~95 values). `pricing_wide` collapses rentals via `MAX(price)` and exposes `rental_days_min/max`.
Sentinel prices ≥ 9999 are nulled (#27).

### price_avg convention
`price_avg` / `*_cost_avg` = `(min + max) / 2`, **NOT** an arithmetic mean (legacy). Label clearly.

## Metabase

Reporting is config-as-code: 62 SQL questions (frontmatter: `-- name:`/`-- display:`/
`-- description:`) in `metabase/questions/`, dashboard JSON in `metabase/dashboards/`, IDs in
`metabase/ids.json` (keyed by filename stem), synced via `metabase/sync.py` (DB id 2). The generated
[`DASHBOARDS-REPORTS.md`](DASHBOARDS-REPORTS.md) inventory groups the dashboards conceptually and
lists each dashboard card as a subsection, plus standalone cards and models. The local image is
built/launched by `metabase.sh`; it connects to `duckdb/commodore.duckdb` and holds a read lock (DB
writes require `docker stop metabase` — see `HANDOFF.md`).
