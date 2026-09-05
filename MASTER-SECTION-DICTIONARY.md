# Master Section release dictionary

Contract for release-facing `master_section`, embedded by `DATA-DICTIONARY.md`. Grain: one
distinct `(period_sortable, section_id)` represented by rolling recent-period canonical `master_material`.
`section_enrollment` retains every valid section, including no-ISBN/no-adoption sections. “Use” is
the issue-#58 population in `CMM-ETL.md`.

All rows below use the following defaults unless overridden: Population/denominator is **Sections**
(material-bearing `master_section` rows); **Items** means canonical items in that section; derived
counts/booleans are non-NULL. DuckDB’s nullable catalog metadata is not this semantic contract.

## Identity, period, institution, and course descriptors

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `section_id` | Section-offering ID | Group key from `master_material`; includes term | Sections | Never NULL |
| `course_id` | Course ID | Section-canonical value inherited through `master_material`; source composite omits section/term | Sections | Missing segments are `UNKNOWN` |
| `period` | Academic period | `ANY_VALUE(period)` from `master_material` | Sections | Valid sortable period required |
| `period_sortable` | Sortable term | `master_material` group key (`YYYY-N`) | Sections | Never NULL |
| `period_date` | Canonical term date | `ANY_VALUE(period_date)` | Recent-period sections | Not NULL in retained scope |
| `unit_id` | IPEDS institution ID | `ANY_VALUE(unit_id)` from `master_material` | Sections | Missing institution ID |
| `state` | State/province | `ANY_VALUE(state)` | Sections | Missing geography |
| `control` | Institution control | Section-canonical value inherited through `master_material` | Sections | No matching IPEDS institution |
| `level` | Institution level | Section-canonical value inherited through `master_material` | Sections | No matching IPEDS institution |
| `size` | Institution size band | `ANY_VALUE(size)` | Sections | No matching IPEDS institution |
| `sector` | IPEDS sector | Section-canonical value inherited through `master_material` | Sections | No matching IPEDS institution |
| `institution_name` | Institution name | `ANY_VALUE(institution_name)` | Sections | No matching IPEDS institution |
| `institution_type` | Institution type | `ANY_VALUE(institution_type)` | Sections | No matching institution/type |
| `enrollment_2024` | Institution enrollment | `ANY_VALUE(enrollment_2024)` | Sections | No matching IPEDS value |
| `distance_enrollment_2024` | Distance enrollment | `ANY_VALUE(distance_enrollment_2024)` | Sections | No matching IPEDS value |
| `school` | School/college | `mode()` of non-NULL `master_material` value | Items | No source value |
| `department` | Department | `mode()` of non-NULL `master_material` value | Items | No source value |
| `course_number` | Course number | `mode()` of non-NULL `master_material` value | Items | No source value |
| `section` | Source section code | `mode()` of non-NULL `master_material` value | Items | No source value |
| `course_title` | Course title | `mode()` of non-NULL `master_material` value | Items | No source value |
| `course_level` | BMG course level | Section-canonical value inherited through `master_material` | Sections | No source value |
| `course_subject` | Course subject | `mode()` of non-NULL `master_material` value | Items | No source value |
| `bookstore_url` | Bookstore URL | Deterministic modal nonblank `master_material.bookstore_url`: count DESC, URL ASC | Items | No nonblank item URL |

`mode()` flattens occasional within-section conflicts; the pipeline logs divergent sections by
descriptor and does not deduplicate underlying catalog rows.

## Material population, classification, and publishers

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `material_count` | Material count | `COUNT(*)` over deduplicated `master_material` | Items | Never NULL/zero |
| `required_count` | Required count | Count where `is_required_inferred` | Items | Zero means none |
| `optional_count` | Optional count | Count where not `is_required_inferred` | Items | Zero means none |
| `is_required_direct` | Direct-required section | `BOOL_OR(is_section_required_direct)` over retained items | Sections | False means no nonsupply literal-required item in the section |
| `has_course_material_use` | Has included material | Constant true for retained sections | Sections | Never false |
| `course_material_use_count` | Included-material audit count | Canonical item count (= `material_count`) | Items | Never zero |
| `course_material_no_use_count` | Excluded-item audit count | `ANY_VALUE(master_material.section_course_material_no_use_count)` | Retained sections | Zero means none |
| `no_details_count` | No-details audit count | `ANY_VALUE(master_material.section_no_details_count)` | Retained sections | Zero means marker absent |
| `no_materials_count` | No-material audit count | `ANY_VALUE(master_material.section_no_materials_count)` | Retained sections | Zero means marker absent |
| `is_canada` | Canadian-section indicator | `ANY_VALUE(master_material.is_section_canada)` | Retained sections | False means no Canadian item |
| `is_supply` | Classified-supply indicator | `ANY_VALUE(master_material.is_section_supply)` | Retained sections | False means no supply item |
| `supply_count` | Supply-item count | `ANY_VALUE(master_material.section_supply_count)` | Retained sections | Zero means none |
| `is_oer` | OER indicator | `BOOL_OR(is_oer)` over `master_material`, coalesced false | Items | False means no classified OER |
| `is_ia` | Inclusive-access indicator | `BOOL_OR(is_ia)` over `master_material`, coalesced false | Items | False means no classified IA |
| `oer_count` | OER count | Count of Items with `is_oer=true` | Items | Zero means none |
| `ia_count` | IA count | Count of Items with `is_ia=true` | Items | Zero means none |
| `publishers` | Material publishers | `LIST(DISTINCT publisher)` for non-NULL publishers | Items | No item publisher |
| `required_publishers` | Required publishers | Distinct publisher list where required | Required Items | No required publisher |
| `required_publisher_count` | Required publisher count | Distinct publisher count where required | Required Items | Zero means none |
| `optional_publisher_count` | Optional publisher count | Distinct publisher count where optional | Optional Items | Zero means none |
| `has_isbn` | Has included ISBN | `BOOL_OR(has_isbn)` over Items | Items | True under current Use contract |
| `has_formattype` | Has classified format | `BOOL_OR(has_formattype)` over Items | Items | False means no nonblank FormatType |
| `isbn_count` | ISBN item count | Count of Items with ISBN (= `material_count` currently) | Items | Never zero |
| `classified_count` | Classified item count | Count of Items with nonblank FormatType | Items | Zero means none |

Checked invariant: `required_count + optional_count = material_count = course_material_use_count`.
The six audit values are canonical section-key aggregates repeated on `master_material` and selected
with `ANY_VALUE`; use `comprehensive_data`/`section_enrollment` for complete-population analysis.

## Enrollment and fill provenance

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `enrollments` | Reported enrollment | Section-canonical value inherited through `master_material` | Sections | Unavailable |
| `seats_taken` | Reported seats | Section-canonical value inherited through `master_material`; raw 9999 retained | Sections | Unavailable |
| `has_enrollment` | Own-enrollment flag | Section-canonical flag inherited through `master_material` | Sections | Never NULL |
| `has_enrollment_sibling` | Sibling-enrollment flag | Full-population section flag inherited through `master_material` | Sections | Never NULL |
| `has_enrollment_own_seats` | Usable-own-seats flag | Section-canonical flag inherited through `master_material` | Sections | Never NULL |
| `has_enrollment_sibling_seats` | Usable-sibling-seats flag | Full-population section flag inherited through `master_material` | Sections | Never NULL |
| `enrollment_assigned` | Assigned enrollment | First available own enrollment, own seats, sibling medians, control×level median, level median | Sections | No rung; source is `none` |
| `enrollment_source` | Enrollment provenance | Section-canonical label inherited through `master_material` | Sections | Never NULL; values `own`, `own_seats`, `sibling_enroll`, `sibling_seats`, `class_median`, `level_median`, `none` |

Medians are per-term, use the documented four BMG levels and six sectors, and are rounded to
integers. Raw enrollment fields remain unchanged.

## Cost and price coverage

`master_section` aggregates canonical `(period_sortable, section_id, isbn13)` Use items from
`master_material`. Missing prices are not zero; Owned is buy-only (not rental); Average is the
legacy midpoint, not arithmetic mean.

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `required_cost_total_min` | Required all-options minimum | Sum required Use ISBN `price_min` | Distinct priced required Items | No valid price |
| `required_cost_total_max` | Required all-options maximum | Sum required Use ISBN `price_max` | Distinct priced required Items | No valid price |
| `optional_cost_total_min` | Optional all-options minimum | Sum optional Use ISBN `price_min` | Distinct priced optional Items | No valid price |
| `optional_cost_total_max` | Optional all-options maximum | Sum optional Use ISBN `price_max` | Distinct priced optional Items | No valid price |
| `required_cost_owned_min` | Required buy minimum | Sum required Use ISBN `price_buy_min` | Buy-priced required Items | No valid buy price |
| `required_cost_owned_max` | Required buy maximum | Sum required Use ISBN `price_buy_max` | Buy-priced required Items | No valid buy price |
| `optional_cost_owned_min` | Optional buy minimum | Sum optional Use ISBN `price_buy_min` | Buy-priced optional Items | No valid buy price |
| `optional_cost_owned_max` | Optional buy maximum | Sum optional Use ISBN `price_buy_max` | Buy-priced optional Items | No valid buy price |
| `required_cost_avg` | Required midpoint | `(required_cost_total_min + required_cost_total_max)/2` | Required total population | Either bound NULL |
| `required_cost_owned_avg` | Required buy midpoint | `(required_cost_owned_min + required_cost_owned_max)/2` | Required owned population | Either bound NULL |
| `optional_cost_avg` | Optional midpoint | `(optional_cost_total_min + optional_cost_total_max)/2` | Optional total population | Either bound NULL |
| `required_priced_count` | Required priced count | Required Items with non-NULL `price_min` | Required Items | Zero means none |
| `optional_priced_count` | Optional priced count | Optional Items with non-NULL `price_min` | Optional Items | Zero means none |

## Release and validation

`scripts/export_cmm_masters.sh` is the sole per-term splitter: select all canonical columns, filter
`period_sortable`, order by `section_id`, and write `master_section_<YYYY_N>_<YYYYMMDD>.csv`; it
does not reimplement population or aggregation. `4_merged_records.sql` checks section-key
uniqueness, encoded-term agreement, `master_material` conservation, required/optional partitioning,
boolean/count agreement, cost bounds, and sidecar invariants. Full-population checks use
`comprehensive_data`/`section_enrollment`; item checks use `course_material`. Reconciliation is in
exports `37_sample10_reconciliation.sql`, `38_cmm_release_reconciliation.sql`, and
`39_cmm_release_key_reconciliation.sql`.
