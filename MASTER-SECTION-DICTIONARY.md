# Master Section release dictionary

This is the per-column contract for the release-facing `master_section` table. Its grain is one
row per period-specific `section_id` for valid 2024+ catalog sections. “Full spine” below means
all such sections, including sections with no canonical Course Materials Use rows. “Use” means
the issue-#58 material population documented in `CMM-ETL.md`.

DuckDB reports every materialized-table column as nullable at the schema level. The NULL column
below describes the semantic contract produced by the SQL, rather than that generic catalog
metadata. Counts and definitive booleans are non-NULL unless explicitly noted.

## Identity, period, institution, and course descriptors

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `section_id` | Section-offering ID | Group key from `comprehensive_data`; includes term | Full spine | Not produced; NULL keys are excluded |
| `course_id` | Course ID | `ANY_VALUE(course_id)`; source composite omits section and term | Full spine | Not expected; missing source segments are encoded as `UNKNOWN` |
| `period` | Academic period | `ANY_VALUE(period)` from catalog | Full spine | Not expected because valid sortable periods are required |
| `period_sortable` | Sortable term | `ANY_VALUE(period_sortable)`; `YYYY-N` | Full spine | Not produced; NULL terms are excluded |
| `period_date` | Canonical term date | `ANY_VALUE(period_date)` from normalized period | Full spine, restricted to 2024+ | Not produced by the retained scope |
| `unit_id` | IPEDS institution ID | `ANY_VALUE(unit_id)` from catalog | Full spine | Source institution ID missing |
| `state` | State/province code | `ANY_VALUE(state)` from the normalized catalog source | Full spine | No source geography |
| `control` | Institution control | `ANY_VALUE(control)` from IPEDS | Full spine | No matching IPEDS institution |
| `level` | Institution level | `ANY_VALUE(level)` from IPEDS | Full spine | No matching IPEDS institution |
| `size` | Institution size band | `ANY_VALUE(size)` from IPEDS | Full spine | No matching IPEDS institution |
| `sector` | IPEDS sector | `ANY_VALUE(sector)` from IPEDS | Full spine | No matching IPEDS institution |
| `institution_name` | Institution name | `ANY_VALUE(institution_name)` from IPEDS | Full spine | No matching IPEDS institution |
| `institution_type` | Institution type | `ANY_VALUE(institution_type)` from IPEDS | Full spine | No matching IPEDS institution/type |
| `enrollment_2024` | Institution enrollment, 2024 | `ANY_VALUE(enrollment_2024)` from IPEDS | Full spine | No matching IPEDS value |
| `distance_enrollment_2024` | Institution distance enrollment, 2024 | `ANY_VALUE(distance_enrollment_2024)` from IPEDS | Full spine | No matching IPEDS value |
| `school` | School/college | Most-frequent non-NULL catalog value via `mode()` | All catalog rows in the section | No non-NULL source value |
| `department` | Department | Most-frequent non-NULL catalog value via `mode()` | All catalog rows in the section | No non-NULL source value |
| `course_number` | Course number | Most-frequent non-NULL catalog value via `mode()` | All catalog rows in the section | No non-NULL source value |
| `section` | Source section code | Most-frequent non-NULL catalog value via `mode()` | All catalog rows in the section | No non-NULL source value |
| `course_title` | Course title | Most-frequent non-NULL catalog value via `mode()` | All catalog rows in the section | No non-NULL source value |
| `course_level` | BMG course level | Most-frequent non-NULL catalog value via `mode()` | All catalog rows in the section | No non-NULL source value |
| `course_subject` | Course subject | Most-frequent non-NULL catalog value via `mode()` | All catalog rows in the section | No non-NULL source value |

`mode()` intentionally flattens occasional within-section source conflicts. The pipeline logs the
number of divergent sections separately for each descriptor; it does not silently deduplicate the
underlying catalog rows.

## Material population, classification, and publishers

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `material_count` | Course-material row count | `COUNT(*) FILTER (is_course_material_use)` | Use catalog rows in the section | Never NULL; zero means no Use row |
| `required_count` | Required material row count | Count of Use rows where `is_required_inferred` | Use catalog rows in the section | Never NULL; zero means none |
| `optional_count` | Optional/supplemental material row count | Count of Use rows where not `is_required_inferred` | Use catalog rows in the section | Never NULL; zero means none |
| `has_course_material_use` | Has an included material | `BOOL_OR(is_course_material_use)`, coalesced false | All catalog rows in the section | Never NULL; false means no Use row |
| `course_material_use_count` | Included material audit count | Count of `is_course_material_use` rows; equals `material_count` | All catalog rows in the section | Never NULL; zero means none |
| `course_material_no_use_count` | Excluded material audit count | Count of `is_course_material_no_use` rows | All catalog rows in the section | Never NULL; zero means none |
| `no_details_count` | No-book-details marker count | Count of exact `*No Book Details*` rows | All catalog rows in the section; reasons may overlap | Never NULL; zero means marker absent |
| `no_materials_count` | No-material marker count | Count of exact `*No Books Required*` or `placeholder_no_material` rows | All catalog rows in the section; reasons may overlap | Never NULL; zero means marker absent |
| `is_canada` | Canadian section indicator | `BOOL_OR(state='CAN')`, coalesced false | All catalog rows in the section | Never NULL; false means no Canadian row |
| `is_supply` | Has a classified supply | `BOOL_OR(is_supply)`, coalesced false | All catalog rows in the section | Never NULL; false means no classified supply |
| `supply_count` | Classified supply row count | Count of `is_supply` rows | All catalog rows in the section | Never NULL; zero means none |
| `is_oer` | Has OER material | `BOOL_OR(is_oer)` over Use rows, coalesced false | Use rows in the section | Never NULL; false includes no Use/classifiable OER row |
| `is_ia` | Has inclusive-access material | `BOOL_OR(is_ia)` over Use rows, coalesced false | Use rows in the section | Never NULL; false includes no Use/classifiable IA row |
| `oer_count` | OER material row count | Count of Use rows with `is_oer=true` | Use rows in the section | Never NULL; zero means none |
| `ia_count` | Inclusive-access material row count | Count of Use rows with `is_ia=true` | Use rows in the section | Never NULL; zero means none |
| `publishers` | Distinct material publishers | `LIST(DISTINCT publisher)` for non-NULL publishers | Use rows in the section | No Use row with a publisher |
| `required_publishers` | Distinct required publishers | `LIST(DISTINCT publisher)` where `is_required_inferred` | Required Use rows in the section | No required Use row with a publisher |
| `required_publisher_count` | Required publisher count | `COUNT(DISTINCT publisher)` where required | Required Use rows in the section | Never NULL; zero means none |
| `optional_publisher_count` | Optional publisher count | `COUNT(DISTINCT publisher)` where not required | Optional Use rows in the section | Never NULL; zero means none |
| `has_isbn` | Has an included ISBN | `BOOL_OR(has_isbn)` over Use rows, coalesced false | Use rows in the section | Never NULL; false means no Use row |
| `has_formattype` | Has a classifiable material | `BOOL_OR(has_formattype)` over Use rows, coalesced false | Use rows in the section | Never NULL; false means no nonblank FormatType on Use rows |
| `isbn_count` | ISBN-bearing material row count | Count of Use rows with `has_isbn`; currently equals `material_count` | Use catalog rows, not distinct ISBNs | Never NULL; zero means none |
| `classified_count` | FormatType-classifiable material row count | Count of Use rows with nonblank `FormatType` | Use catalog rows | Never NULL; zero means none |

`required_count + optional_count = material_count = course_material_use_count` is a checked
invariant. Supply, Canada, and placeholder counts deliberately use the full source-row population
so excluded evidence remains visible.

## Enrollment and fill provenance

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `enrollments` | Reported section enrollment | `MAX(enrollments)` across source rows | All catalog rows in the section | No reported enrollment |
| `seats_taken` | Reported seats taken | `MAX(seats_taken)` across source rows; raw 9999 sentinel retained | All catalog rows in the section | No reported seats value |
| `has_enrollment` | Has own enrollment | `MAX(enrollments) IS NOT NULL` | Full spine | Never NULL |
| `has_enrollment_sibling` | Sibling has enrollment | Another section with the same course and term has enrollment | Full spine | Never NULL |
| `has_enrollment_own_seats` | Has usable own seats | `MAX(seats_taken)` is non-NULL and below 9999 | Full spine | Never NULL |
| `has_enrollment_sibling_seats` | Sibling has usable seats | Another section with the same course and term has seats below 9999 | Full spine | Never NULL |
| `enrollment_assigned` | Assigned section enrollment | First available of own enrollment, own seats, sibling medians, control×level median, or level median; rounded integer | Full spine; medians use the documented per-term BMG reference population | No rung produced a value (`enrollment_source='none'`) |
| `enrollment_source` | Enrollment provenance | Label for the selected fill rung | Full spine | Never NULL; `none` means unassigned |

Valid `enrollment_source` values are `own`, `own_seats`, `sibling_enroll`, `sibling_seats`,
`class_median`, `level_median`, and `none`. Raw enrollment fields are never overwritten.

## Cost and price coverage

Cost fields come from `section_cost`, whose material grain is distinct `(section_id, ISBN13)` over
Use rows. A material contributes only when the named pricing bound exists; missing prices are not
treated as zero. “Owned” means buy-only and excludes rental cells. “Average” is the legacy midpoint,
not an arithmetic mean.

| Column | Business label | Source / derivation | Population / denominator | NULL meaning |
|---|---|---|---|---|
| `required_cost_total_min` | Required cost, all-options minimum | Sum of each required Use ISBN's `pricing_wide.price_min` | Distinct priced required Use materials in the section | No required Use material has a valid price |
| `required_cost_total_max` | Required cost, all-options maximum | Sum of each required Use ISBN's `pricing_wide.price_max` | Distinct priced required Use materials in the section | No required Use material has a valid price |
| `optional_cost_total_min` | Optional cost, all-options minimum | Sum of each optional Use ISBN's `pricing_wide.price_min` | Distinct priced optional Use materials in the section | No optional Use material has a valid price |
| `optional_cost_total_max` | Optional cost, all-options maximum | Sum of each optional Use ISBN's `pricing_wide.price_max` | Distinct priced optional Use materials in the section | No optional Use material has a valid price |
| `required_cost_owned_min` | Required buy-only minimum | Sum of each required Use ISBN's `price_buy_min` | Distinct required Use materials with a buy price | No required Use material has a valid buy price |
| `required_cost_owned_max` | Required buy-only maximum | Sum of each required Use ISBN's `price_buy_max` | Distinct required Use materials with a buy price | No required Use material has a valid buy price |
| `optional_cost_owned_min` | Optional buy-only minimum | Sum of each optional Use ISBN's `price_buy_min` | Distinct optional Use materials with a buy price | No optional Use material has a valid buy price |
| `optional_cost_owned_max` | Optional buy-only maximum | Sum of each optional Use ISBN's `price_buy_max` | Distinct optional Use materials with a buy price | No optional Use material has a valid buy price |
| `required_cost_avg` | Required all-options midpoint | (`required_cost_total_min` + `required_cost_total_max`) / 2 | Same priced required population as the total bounds | Either total bound is NULL |
| `required_cost_owned_avg` | Required buy-only midpoint | (`required_cost_owned_min` + `required_cost_owned_max`) / 2 | Same buy-priced required population as the owned bounds | Either owned bound is NULL |
| `optional_cost_avg` | Optional all-options midpoint | (`optional_cost_total_min` + `optional_cost_total_max`) / 2 | Same priced optional population as the total bounds | Either total bound is NULL |
| `required_priced_count` | Required priced material count | Distinct required Use ISBNs with non-NULL `price_min` | Required Use materials in the section | NULL only when the section has no Use row; zero means Use rows exist but none are priced |
| `optional_priced_count` | Optional priced material count | Distinct optional Use ISBNs with non-NULL `price_min` | Optional Use materials in the section | NULL only when the section has no Use row; zero means Use rows exist but none are priced |

## Release and validation

`scripts/export_cmm_masters.sh` is the sole per-term release splitter. It selects every column from
the canonical materialized table, filters only `period_sortable`, orders by `section_id`, and writes
`master_section_<YYYY_N>_<YYYYMMDD>.csv`. It does not reimplement any population or aggregation.

The executable DQ in `scripts/sql/4_merged_records.sql` checks section-key uniqueness, encoded-term
agreement, source/master row conservation, Use/NoUse conservation, required/optional partitioning,
boolean/count agreement, cost bounds, and the Canada subset invariant. Cross-model and deterministic
sample reconciliation is in `scripts/sql/exports/37_sample10_reconciliation.sql`; exact current-state
release and key-set reconciliation is in `scripts/sql/exports/38_cmm_release_reconciliation.sql`
and `39_cmm_release_key_reconciliation.sql`.
