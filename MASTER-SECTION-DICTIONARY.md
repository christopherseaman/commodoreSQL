# Master Section release dictionary

This repo-level appendix is the detailed business, NULL, population, and denominator contract for
the release-facing `master_section` table. The generated project-wide `DATA-DICTIONARY.md` embeds
this appendix so the synced Data Dictionary page remains self-contained. Its grain is one
row per distinct `(period_sortable, section_id)` represented by canonical `material_costs` for
2024+ terms. “Material-section population” below means those sections; the independent
`section_enrollment` table retains the complete valid section population, including no-ISBN and
no-adoption sections. “Use” means the issue-#58 material population documented in `CMM-ETL.md`.

DuckDB reports every materialized-table column as nullable at the schema level. The NULL column
below describes the semantic contract produced by the SQL, rather than that generic catalog
metadata. Counts and definitive booleans are non-NULL unless explicitly noted.

## Identity, period, institution, and course descriptors

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `section_id` | Section-offering ID | Group key from `material_costs`; includes term | Material-section population | Not produced |
| `course_id` | Course ID | Exact section value from `section_enrollment`; source composite omits section and term | Material-section population | Not expected; missing source segments are encoded as `UNKNOWN` |
| `period` | Academic period | `ANY_VALUE(period)` from `material_costs` | Material-section population | Not expected because valid sortable periods are required |
| `period_sortable` | Sortable term | Group key from `material_costs`; `YYYY-N` | Material-section population | Not produced |
| `period_date` | Canonical term date | `ANY_VALUE(period_date)` from `material_costs` | Material-section population, restricted to 2024+ | Not produced by the retained scope |
| `unit_id` | IPEDS institution ID | `ANY_VALUE(unit_id)` from `material_costs` | Material-section population | Source institution ID missing |
| `state` | State/province code | `ANY_VALUE(state)` from `material_costs` | Material-section population | No source geography |
| `control` | Institution control | Exact section value from `section_enrollment` | Material-section population | No matching IPEDS institution |
| `level` | Institution level | Exact section value from `section_enrollment` | Material-section population | No matching IPEDS institution |
| `size` | Institution size band | `ANY_VALUE(size)` from `material_costs` | Material-section population | No matching IPEDS institution |
| `sector` | IPEDS sector | Exact section value from `section_enrollment` | Material-section population | No matching IPEDS institution |
| `institution_name` | Institution name | `ANY_VALUE(institution_name)` from `material_costs` | Material-section population | No matching IPEDS institution |
| `institution_type` | Institution type | `ANY_VALUE(institution_type)` from `material_costs` | Material-section population | No matching IPEDS institution/type |
| `enrollment_2024` | Institution enrollment, 2024 | `ANY_VALUE(enrollment_2024)` from `material_costs` | Material-section population | No matching IPEDS value |
| `distance_enrollment_2024` | Institution distance enrollment, 2024 | `ANY_VALUE(distance_enrollment_2024)` from `material_costs` | Material-section population | No matching IPEDS value |
| `school` | School/college | Most-frequent non-NULL `material_costs` value via `mode()` | Canonical items in the section | No non-NULL source value |
| `department` | Department | Most-frequent non-NULL `material_costs` value via `mode()` | Canonical items in the section | No non-NULL source value |
| `course_number` | Course number | Most-frequent non-NULL `material_costs` value via `mode()` | Canonical items in the section | No non-NULL source value |
| `section` | Source section code | Most-frequent non-NULL `material_costs` value via `mode()` | Canonical items in the section | No non-NULL source value |
| `course_title` | Course title | Most-frequent non-NULL `material_costs` value via `mode()` | Canonical items in the section | No non-NULL source value |
| `course_level` | BMG course level | Exact section value from `section_enrollment` | Material-section population | No non-NULL source value |
| `course_subject` | Course subject | Most-frequent non-NULL `material_costs` value via `mode()` | Canonical items in the section | No non-NULL source value |

`mode()` intentionally flattens occasional within-section source conflicts. The pipeline logs the
number of divergent sections separately for each descriptor; it does not silently deduplicate the
underlying catalog rows.

## Material population, classification, and publishers

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `material_count` | Course-material item count | `COUNT(*)` over deduplicated `material_costs` | Canonical section×ISBN items | Never NULL or zero |
| `required_count` | Required material item count | Count of `material_costs` rows where `is_required_inferred` | Canonical items in the section | Never NULL; zero means none |
| `optional_count` | Optional/supplemental material item count | Count of `material_costs` rows where not `is_required_inferred` | Canonical items in the section | Never NULL; zero means none |
| `has_course_material_use` | Has an included material | Constant true for a retained material section | Material-section population | Never NULL or false |
| `course_material_use_count` | Included material audit count | Count of canonical items; equals `material_count` | Canonical items in the section | Never NULL or zero |
| `course_material_no_use_count` | Co-occurring excluded-row audit | Count of `course_materials.is_course_material_no_use` rows | Canonical rows for retained material sections only | Never NULL; zero means none |
| `no_details_count` | Co-occurring no-book-details audit | Count of exact `*No Book Details*` rows in the sidecar | Canonical `course_materials` rows for retained material sections only; reasons may overlap | Never NULL; zero means marker absent |
| `no_materials_count` | Co-occurring no-material audit | Count of exact `*No Books Required*` or `placeholder_no_material` rows in the sidecar | Canonical `course_materials` rows for retained material sections only; reasons may overlap | Never NULL; zero means marker absent |
| `is_canada` | Co-occurring Canadian-row indicator | `BOOL_OR(state='CAN')` in the sidecar | Canonical `course_materials` rows for retained material sections only | Never NULL; false means no Canadian row |
| `is_supply` | Has a co-occurring classified supply | `BOOL_OR(is_supply)` in the sidecar | Canonical `course_materials` rows for retained material sections only | Never NULL; false means no classified supply |
| `supply_count` | Co-occurring classified supply row count | Count of `is_supply` rows in the sidecar | Canonical `course_materials` rows for retained material sections only | Never NULL; zero means none |
| `is_oer` | Has OER material | `BOOL_OR(is_oer)` over `material_costs`, coalesced false | Canonical items in the section | Never NULL; false means no classified OER item |
| `is_ia` | Has inclusive-access material | `BOOL_OR(is_ia)` over `material_costs`, coalesced false | Canonical items in the section | Never NULL; false means no classified IA item |
| `oer_count` | OER material item count | Count of canonical items with `is_oer=true` | Canonical items in the section | Never NULL; zero means none |
| `ia_count` | Inclusive-access material item count | Count of canonical items with `is_ia=true` | Canonical items in the section | Never NULL; zero means none |
| `publishers` | Distinct material publishers | `LIST(DISTINCT publisher)` for non-NULL `material_costs` publishers | Canonical items in the section | No canonical item has a publisher |
| `required_publishers` | Distinct required publishers | `LIST(DISTINCT publisher)` where `is_required_inferred` | Required canonical items in the section | No required item has a publisher |
| `required_publisher_count` | Required publisher count | `COUNT(DISTINCT publisher)` where required | Required canonical items in the section | Never NULL; zero means none |
| `optional_publisher_count` | Optional publisher count | `COUNT(DISTINCT publisher)` where not required | Optional canonical items in the section | Never NULL; zero means none |
| `has_isbn` | Has an included ISBN | `BOOL_OR(has_isbn)` over `material_costs` | Canonical items in the section | Never NULL; true under the current Use contract |
| `has_formattype` | Has a classifiable material | `BOOL_OR(has_formattype)` over `material_costs` | Canonical items in the section | Never NULL; false means no nonblank FormatType |
| `isbn_count` | ISBN-bearing material item count | Count of canonical items with `has_isbn`; currently equals `material_count` | Canonical section×ISBN items | Never NULL or zero |
| `classified_count` | FormatType-classifiable material item count | Count of canonical items with nonblank `FormatType` | Canonical items in the section | Never NULL; zero means none |

`required_count + optional_count = material_count = course_material_use_count` is a checked
invariant. Supply, Canada, NoUse, and placeholder counts are sidecar evidence only for retained
sections; use `comprehensive_data` or `section_enrollment` for complete-population analysis.
The validated canonical sidecar after the #65 rebuild totals
`course_material_no_use_count=78,230`, `no_details_count=25,993`,
`no_materials_count=145`, and `supply_count=52,237`; these replace the old raw-row comparisons
for the retained material-bearing sections.

## Enrollment and fill provenance

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `enrollments` | Reported section enrollment | Exact section value from `section_enrollment` | Material-section rows; computed upstream over the full section population | No reported enrollment |
| `seats_taken` | Reported seats taken | Exact section value from `section_enrollment`; raw 9999 sentinel retained | Material-section rows; computed upstream over the full section population | No reported seats value |
| `has_enrollment` | Has own enrollment | Exact flag from `section_enrollment` | Material-section rows | Never NULL |
| `has_enrollment_sibling` | Sibling has enrollment | Exact flag from `section_enrollment` | Material-section rows; sibling search occurs upstream over the full population | Never NULL |
| `has_enrollment_own_seats` | Has usable own seats | Exact flag from `section_enrollment` | Material-section rows | Never NULL |
| `has_enrollment_sibling_seats` | Sibling has usable seats | Exact flag from `section_enrollment` | Material-section rows; sibling search occurs upstream over the full population | Never NULL |
| `enrollment_assigned` | Assigned section enrollment | Exact assignment from `section_enrollment`; first available of own enrollment, own seats, sibling medians, control×level median, or level median | Material-section rows; medians use the documented per-term full reference population | No rung produced a value (`enrollment_source='none'`) |
| `enrollment_source` | Enrollment provenance | Exact label from `section_enrollment` | Material-section rows | Never NULL; `none` means unassigned |

Valid `enrollment_source` values are `own`, `own_seats`, `sibling_enroll`, `sibling_seats`,
`class_median`, `level_median`, and `none`. Raw enrollment fields are never overwritten.

## Cost and price coverage

Cost fields come from `section_cost`, which aggregates canonical `(period_sortable, section_id,
isbn13)` Use items from `material_costs`. A material contributes only when the named pricing bound exists; missing prices are not
treated as zero. “Owned” means buy-only and excludes rental cells. “Average” is the legacy midpoint,
not an arithmetic mean.

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `required_cost_total_min` | Required cost, all-options minimum | Sum of each required Use ISBN's `material_costs.price_min` | Distinct priced required Use materials in the section | No required Use material has a valid price |
| `required_cost_total_max` | Required cost, all-options maximum | Sum of each required Use ISBN's `material_costs.price_max` | Distinct priced required Use materials in the section | No required Use material has a valid price |
| `optional_cost_total_min` | Optional cost, all-options minimum | Sum of each optional Use ISBN's `material_costs.price_min` | Distinct priced optional Use materials in the section | No optional Use material has a valid price |
| `optional_cost_total_max` | Optional cost, all-options maximum | Sum of each optional Use ISBN's `material_costs.price_max` | Distinct priced optional Use materials in the section | No optional Use material has a valid price |
| `required_cost_owned_min` | Required buy-only minimum | Sum of each required Use ISBN's `material_costs.price_buy_min` | Distinct required Use materials with a buy price | No required Use material has a valid buy price |
| `required_cost_owned_max` | Required buy-only maximum | Sum of each required Use ISBN's `material_costs.price_buy_max` | Distinct required Use materials with a buy price | No required Use material has a valid buy price |
| `optional_cost_owned_min` | Optional buy-only minimum | Sum of each optional Use ISBN's `material_costs.price_buy_min` | Distinct optional Use materials with a buy price | No optional Use material has a valid buy price |
| `optional_cost_owned_max` | Optional buy-only maximum | Sum of each optional Use ISBN's `material_costs.price_buy_max` | Distinct optional Use materials with a buy price | No optional Use material has a valid buy price |
| `required_cost_avg` | Required all-options midpoint | (`required_cost_total_min` + `required_cost_total_max`) / 2 | Same priced required population as the total bounds | Either total bound is NULL |
| `required_cost_owned_avg` | Required buy-only midpoint | (`required_cost_owned_min` + `required_cost_owned_max`) / 2 | Same buy-priced required population as the owned bounds | Either owned bound is NULL |
| `optional_cost_avg` | Optional all-options midpoint | (`optional_cost_total_min` + `optional_cost_total_max`) / 2 | Same priced optional population as the total bounds | Either total bound is NULL |
| `required_priced_count` | Required priced material count | Required canonical ISBN items with non-NULL `price_min` | Required items in the section | Never NULL; zero means none has a valid price |
| `optional_priced_count` | Optional priced material count | Optional canonical ISBN items with non-NULL `price_min` | Optional items in the section | Never NULL; zero means none has a valid price |

## Release and validation

`scripts/export_cmm_masters.sh` is the sole per-term release splitter. It selects every column from
the canonical materialized table, filters only `period_sortable`, orders by `section_id`, and writes
`master_section_<YYYY_N>_<YYYYMMDD>.csv`. It does not reimplement any population or aggregation.

The executable DQ in `scripts/sql/4_merged_records.sql` checks section-key uniqueness, encoded-term
agreement, exact `material_costs` section-key conservation, required/optional partitioning,
boolean/count agreement, cost bounds, and retained-section sidecar invariants. Full-population
checks remain on `comprehensive_data`/`section_enrollment`; canonical item checks use
`course_materials`. Cross-model and deterministic sample
reconciliation is in `scripts/sql/exports/37_sample10_reconciliation.sql`; exact current-state
release and material-section key-set reconciliation is in
`scripts/sql/exports/38_cmm_release_reconciliation.sql` and
`39_cmm_release_key_reconciliation.sql`.
