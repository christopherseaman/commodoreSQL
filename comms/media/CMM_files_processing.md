---
extracted-from: CMM_files_processing.docx
source-sha256: 21bd093fe15ac46fcd33d635547038cdc73a2e627123709ccae4f488f90e6330
extraction: python-docx 1.2.0
---

## Create augmented course materials file

Input file: BMG_CourseMaterial_YYYYMMDD

Processing:

1) Add reformatted and flag variables

- sortable date

- is_ia flag

- is_oer flag

- is_supply flag

- has_isbn flag

- has_formattype flag

- has_enrollment flag

- has_enrollment_own_seats flag

- no_details flag

- no_materials flag

2) Add computed IDs

- Section ID

- Course ID

2) Merge selected IPEDS data using unit_id

3) Merge discipline groupings using department

4) Merge opt_out flag using email address

5) Add computed variables across records

- Is Required Inferred

- Has Enrollment Sibling

- Has Enrollment Sibling Seats

- Enrollment Assigned

- Enrollment Source

Output file: BVA_CourseMaterial_YYYYMMDD

## Create subset post 2024 Course Materials

Input file: BVA_CourseMaterial_YYYYMMDD

1) Select 2024 and later

Output file: BVA_CourseMaterial_Post_2024_YYYYMMDD

## Create subset Course Materials

Input file: BVA_CourseMaterial_Post_2024_YYYYMMDD

1) Select

2) Divide file

- Canada Output file: BVA_CourseMaterial_CAN_Post_2024_YYYYMMDD

- Use Output file: BVA_CourseMaterial_Use_Post_2024_YYYYMMDD

- is_supply flag

- no_details flag

- no_materials flag

- has_isbn flag

- NoUse file: BVA_CourseMaterial_NoUse_Post_2024_YYYYMMDD

- All records omitted from BVA_CourseMaterial_Use_Post_2024

## Create Master Course Materials Cost file

Input file: BVA_CourseMaterial_Use_Post_2024_YYYYMMDD

Input file: BMG_Costs_YYYYMMDD

Add data from BMG_Costs file to BVA_CourseMaterial_Use_Post_2024 file (one-many merge)

- Bookstore URL

- Price Buy New Physical

- Price Buy New Digital

- Price Buy New Na

- Price Buy Used Physical

- Price Buy Used Digital

- Price Buy Used Na

- Price Buy Na Physical

- Price Buy Na Digital

- Price Buy Na Na

- Price Rental New Physical

- Price Rental New Digital

- Price Rental New Na

- Price Rental Used Physical

- Price Rental Used Digital

- Price Rental Used Na

- Price Rental Na Physical

- Price Rental Na Digital

- Price Rental Na Na

- Format Count

- Has Buy

- Has Rent

- Price Min

- Price Max

- Price Avg

- Rental Days Min

- Rental Days Max

- Price Buy Min

- Price Buy Max

Output file: BVA_Material_Costs_YYYYMMDD

## Create subset Course Material Cost file by term

Input file: BVA_Material_Costs_YYYYMMDD

1) Divide file

One file for each term starting in 2024

- Output file: BVA_Material_Costs_2024_1_YYYYMMDD

- Output file: BVA_Material_Costs_2024_2_YYYYMMDD

- Etc.

## Create master section record

Input file: BVA_Material_Costs_YYYYMMDD

Output file: BVA_Section_Master_YYYYMMDD

## Create subset Section file by term

Input file: BVA_Section_Master_YYYYMMDD

1) Divide file

One file for each term

- Output file: BVA_Section_2024_1_YYYYMMDD

- Output file: BVA_Section_2024_2_YYYYMMDD

- Etc.

## Create master mailing list file

Input file: BVA_CourseMaterial_YYYYMMDD

1) Select records

- Unique email address

- No opt-out flag

- Most recent time period

- Largest enrollment

- Random

Output file: BVA_Mailing_Master_YYYYMMDD

## Create geographic mailing list files

Input file: BVA_Mailing_Master_YYYYMMDD

1) Divide file

- Canada file: BVA_Mailing_CAN_YYYYMMDD

- Texas file: BVA_Mailing_TX_YYYYMMDD

- California file: BVA_Mailing_CA_YYYYMMDD

- New York file: BVA_Mailing_NY_YYYYMMDD

- Florida file: BVA_Mailing_FL_YYYYMMDD

- Pennsylvania file: BVA_Mailing_PA_YYYYMMDD

- All others file: BVA_Mailing_Oth_YYYYMMDD

## Create Master Institution list

Input file: Most recent BVA_Section_20xx_x_YYYYMMDD

Create one record per institution

| Variable | Source |
| --- | --- |
| unit_id | IPEDS value |
| state | IPEDS value |
| control | IPEDS value |
| level | IPEDS value |
| size | IPEDS value |
| institution_name | IPEDS value |
| institution_type | IPEDS value |
| enrollment_2024 | IPEDS value |
| distance_enrollment_2024 | IPEDS value |
| bookstore_URL | Value for institution |
| section_id | Count of unique sections |
| Advanced graduate | Count of sections with this course level |
| Advanced graduate/ directed study and research | Count of sections with this course level |
| Advanced undergraduate | Count of sections with this course level |
| Advanced undergraduate/ graduate | Count of sections with this course level |
| General graduate | Count of sections with this course level |
| Intermediate undergraduate | Count of sections with this course level |
| Introductory or general undergraduate | Count of sections with this course level |
| Non-degree credit | Count of sections with this course level |
| Uncategorized | Count of sections with this course level |
| course_id | Count of unique courses |
| material_count | Count of sections with material |
| required_count | Count of sections with required material |
| Inferred_required_count | Count of sections with inferred required material |
| optional_count | Count of sections with optional material |
| supply_count | Count of sections with supplies |
| oer_count | Count of sections with OER |
| ia_count | Count of sections with IA |
| Req_priced_count | Count of sections with optional prices |
| Opt_priced_count | Count of sections with required prices |
| isbn_count | Count of section with ISBN |
| enrollments | Count of section with enrollment assigned |
| seats_taken | Count of section with seats taken |
| enrollments_tot | Total of enrollment assigned (sum over all section records for this institution) |
| seats_taken_tot | Total of seats taken (sum over all section records for this institution) |

Output file: BVA_Institution_Master_20xx_x_YYYYMMDD

## Create Master ISBN file

Input file: BVA_Material_Costs_2025_2_YYYYMMDD

One record per ISBN

| Variable | Source |
| --- | --- |
| ISBN13 | Value for ISBN |
| book_title | Value for ISBN |
| Author | Value for ISBN |
| Publisher | Value for ISBN |
| is_oer | Value for ISBN |
| is_ia | Value for ISBN |
| Is_supply | Value for ISBN |
| unit_id_cnt | Count of unique institutions |
| section_id_cnt | Count of unique sections |
| course_id_cnt | Count of unique courses |
| enroll_cnt | Count of sections with assigned enrollment |
| enroll_tot | Sum of assigned enrollments for all sections |
| price_buy_new_physical | Count of records containing a value for this |
| price_buy_na_physical | Count of records containing a value for this |
| price_buy_used_physical | Count of records containing a value for this |
| price_buy_new_digital | Count of records containing a value for this |
| price_buy_na_digital | Count of records containing a value for this |
| price_rental_new_physical | Count of records containing a value for this |
| price_rental_used_physical | Count of records containing a value for this |
| price_rental_new_digital | Count of records containing a value for this |
| price_rental_new_na | Count of records containing a value for this |
| price_rental_na_physical | Count of records containing a value for this |
| price_rental_na_digital | Count of records containing a value for this |
| 2 Year Private Profit | Count of records with this institution_type |
| 2 Year Private | Count of records with this institution_type |
| 2 Year Public | Count of records with this institution_type |
| 4 Year Private Profit | Count of records with this institution_type |
| 4 Year Private | Count of records with this institution_type |
| 4 Year Public | Count of records with this institution_type |

Output file: BVA_ISBN_Master_2025_4_YYYYMMDD
