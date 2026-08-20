---
extracted-from: Master_Institution_ISBN.xlsx
source-sha256: 5af8b5e2e0a2beab402ebb9b90d16bd8077c1ae51ee93a1797e75ce42b65ed91
extraction: openpyxl 3.1.5
---

# Master Institution / Master ISBN workbook

The workbook contains two worksheets. Their cell-level contents are preserved in:

- [Master Institution CSV](Master_Institution_ISBN.Master_Institution.csv)
- [Master ISBN CSV](Master_Institution_ISBN.Master_ISBN.csv)

## `Master_Institution`

Requested grain: one record per institution for `period_sortable = '2025-4'`, eventually one file for each time period beginning in 2024. The worksheet says this can be created from master-section records except for `bookstore_URL`, which comes from pricing data.

Requested fields:

| Variable | Requested source or calculation |
| --- | --- |
| `period_sortable` | Select only `2025-4` |
| `unit_id`, `state`, `control`, `level`, `size`, `institution_name`, `institution_type`, `enrollment_2024`, `distance_enrollment_2024` | Institution value |
| `bookstore_URL` | Institution value from pricing data |
| `section_id` | Count of unique sections |
| `Advanced graduate` | Count of sections with this course level |
| `Advanced graduate/ directed study and research` | Count of sections with this course level |
| `Advanced undergraduate` | Count of sections with this course level |
| `Advanced undergraduate/ graduate` | Count of sections with this course level |
| `General graduate` | Count of sections with this course level |
| `Intermediate undergraduate` | Count of sections with this course level |
| `Introductory or general undergraduate` | Count of sections with this course level |
| `Non-degree credit` | Count of sections with this course level |
| `Uncategorized` | Count of sections with this course level |
| `course_id` | Count of unique courses |
| `material_count` | Count of sections with material |
| `required_count` | Count of sections with required material |
| `Inferred_required_count` | Count of sections with inferred required material |
| `optional_count` | Count of sections with optional material |
| `supply_count` | Count of sections with supplies |
| `oer_count` | Count of sections with OER |
| `ia_count` | Count of sections with IA |
| `Req_priced_count` | Count of sections with optional prices |
| `Opt_priced_count` | Count of sections with required prices |
| `isbn_count` | Count of sections with ISBN |
| `enrollments` | Count of sections with enrollments |
| `seats_taken` | Count of sections with seats taken |
| `enrollments_tot` | Sum of enrollments over all section records for the institution |
| `seats_taken_tot` | Sum of seats taken over all section records for the institution |

## `Master_ISBN`

Requested grain: one record per ISBN for `period_sortable = '2025-4'`, eventually one file for each time period beginning in 2024.

Requested fields:

| Variable | Requested source or calculation |
| --- | --- |
| `period_sortable` | Select only `2025-4` |
| `ISBN13`, `book_title`, `Author`, `Publisher`, `is_oer`, `is_ia` | Value for ISBN |
| `unit_id` | Count of unique institutions |
| `section_id` | Count of unique sections |
| `course_id` | Count of unique courses |
| `price_buy_new_physical`, `price_buy_na_physical`, `price_buy_used_physical`, `price_buy_new_digital`, `price_buy_na_digital` | Count of records containing a value |
| `price_rental_new_physical`, `price_rental_used_physical`, `price_rental_new_digital`, `price_rental_new_na`, `price_rental_na_physical`, `price_rental_na_digital` | Count of records containing a value |
| `2 Year Priavte Profit`, `2 Year Private`, `2 Year Public`, `4 Year Priavte Profit`, `4 Year Private`, `4 Year Public` | Count of records with the institution type |

## Source discrepancies to resolve

These are preserved source discrepancies, not corrections made during extraction:

- The workbook describes `Req_priced_count` as optional-price sections and `Opt_priced_count` as required-price sections. The Word attachment repeats this apparently reversed wording.
- The Word table adds `Is_supply`, `enroll_cnt`, and `enroll_tot` to Master ISBN and renames the distinct-key counts to `unit_id_cnt`, `section_id_cnt`, and `course_id_cnt`; the workbook does not.
- The Word table defines institution `enrollments` as sections with assigned enrollment, while the workbook says sections with enrollments.
- The Word workflow names `BVA_Material_Costs_2025_2_YYYYMMDD` as the Master ISBN input but names the output `BVA_ISBN_Master_2025_4_YYYYMMDD`.
- Spelling and capitalization above are faithful to the workbook, including `Priavte`, `Instituion`, and `bookstore_URL`.
