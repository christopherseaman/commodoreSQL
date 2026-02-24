# CommodoreSQL Database Schema

## Overview

This database integrates course catalog data with institutional information, panel responses, and opt-out lists to support targeted mailing list generation and OER/IA analysis.

**Database Engine:** DuckDB
**Total Records:** ~102.9M course catalog records
**Last Updated:** 2025-12-15

---

## Source Data Files

| File | Records | Description |
|------|---------|-------------|
| `DiscoveryExtract.20251215.csv` | 102.9M | Course catalog with instructor, course, and material information |
| `IPEDS_2024.csv` | ~7K | Institutional characteristics from IPEDS |
| `OptOut_20251215.csv` | Variable | Email addresses that opted out of communications |
| `panel_20260108.csv` | Variable | Panel response data by email |
| `format_type_lookup.tsv` | 69 | OER and IA classification by FormatType |
| `Bookpricing Report Sample 12042023 (2).xlsx` | 10,795 | Institutional bookstore pricing (sample) |
| `Sample Publisher Pricing Report.xlsx` | 606 | Publisher list pricing (sample) |

---

## Core Tables

### course_catalog_20251215

**Purpose:** Normalized course catalog data imported from Discovery extract
**Row Count:** 102,885,609
**Primary Key:** None (raw data table)

| Column | Type | Description |
|--------|------|-------------|
| `ISBN13` | BIGINT | ISBN-13 identifier for course materials |
| `Title` | VARCHAR | Material title |
| `Author` | VARCHAR | Material author(s) |
| `Publisher` | VARCHAR | Publisher name |
| `Imprint` | VARCHAR | Publisher imprint |
| `Format` | VARCHAR | Material format (general) |
| `FormatType` | VARCHAR | Detailed format type (see FormatType values below) |
| `book_status` | VARCHAR | Required, Recommended, Option, or NULL |
| `unit_id` | BIGINT | IPEDS institution identifier |
| `school` | VARCHAR | School/college within institution |
| `state` | VARCHAR | Two-letter state code (e.g., 'CA', 'TX') |
| `department` | VARCHAR | Academic department |
| `dept_description` | VARCHAR | Department description |
| `course_number` | VARCHAR | Course number/code |
| `section` | VARCHAR | Section identifier |
| `course_title` | VARCHAR | Course title |
| `course_level` | VARCHAR | Course level (e.g., Undergraduate, Graduate) |
| `course_subject` | VARCHAR | Subject area |
| `period` | VARCHAR | Term period (e.g., "Fall 2024") |
| `enrollments` | INTEGER | Number of enrolled students |
| `seats_taken` | INTEGER | Number of seats taken |
| `instructor` | VARCHAR | Instructor full name |
| `first_name` | VARCHAR | Instructor first name |
| `last_name` | VARCHAR | Instructor last name |
| `email` | VARCHAR | Cleaned instructor email address |
| `course_id` | VARCHAR | Composite: school::department::course_number |
| `section_id` | VARCHAR | Composite: school::department::course_number::section |
| `period_sortable` | VARCHAR | Sortable period code (YYYY-N: 2024-1 = Winter, -2 = Spring, -3 = Summer, -4 = Fall) |

**Excluded Source Columns:**
- `Edition` - Not needed for current analysis
- `Published Year` - Not needed for current analysis
- `SchoolYearType` - Not needed for current analysis
- `Dept Code` - Have dept_description instead

**Indexes:**
- `idx_course_email` on (email)
- `idx_course_unitid` on (unit_id)
- `idx_course_period` on (period_sortable)
- `idx_course_courseid` on (course_id)
- `idx_course_sectionid` on (section_id)

---

### ipeds_data

**Purpose:** IPEDS institutional characteristics
**Row Count:** ~7,000 institutions

| Column | Type | Description |
|--------|------|-------------|
| `unitid` | INTEGER | IPEDS institution identifier |
| `instnm` | VARCHAR | Institution name |
| `sector` | INTEGER | Sector code (public/private, 2yr/4yr) |
| `iclevel` | INTEGER | Level code (4-year, 2-year, less than 2-year) |
| `control` | INTEGER | Control code (public, private nonprofit, private for-profit) |
| `instsize` | INTEGER | Size category |
| `enroll_24` | INTEGER | Total enrollment 2024 |
| `dist_enroll_24` | INTEGER | Distance education enrollment 2024 |
| `inst_type` | VARCHAR | Institution type description |

---

### opt_out

**Purpose:** Email addresses that opted out of communications
**Source:** OptOut_20251215.csv

| Column | Type | Description |
|--------|------|-------------|
| `email` | VARCHAR | Normalized email address (lowercase, trimmed) |
| `source` | VARCHAR | Source of opt-out |

---

### panel

**Purpose:** Panel response tracking
**Source:** panel_20260108.csv

| Column | Type | Description |
|--------|------|-------------|
| `email` | VARCHAR | Normalized email address |
| `response_year` | VARCHAR | Year of panel response |

---

### format_type_classification

**Purpose:** OER and IA classification lookup
**Source:** format_type_lookup.tsv
**Row Count:** 69 format types

| Column | Type | Description |
|--------|------|-------------|
| `FormatType` | VARCHAR | Format type value (matches course_catalog_20251215.FormatType) |
| `is_oer` | BOOLEAN | True if format type includes Open Educational Resource |
| `oer_category` | VARCHAR | OER category (book_oer, ebook_oer, courseware_oer, etc.) |
| `is_ia` | BOOLEAN | True if format type includes Inclusive Access |
| `ia_category` | VARCHAR | IA category (book_ia, ebook_ia, courseware_ia, etc.) |

**Key Categories:**
- **OER Categories:** book_oer, ebook_oer, bundle_oer, courseware_oer, digital_oer, homework_oer, loose_leaf_oer, pure_oer, non_oer
- **IA Categories:** book_ia, ebook_ia, bundle_ia, courseware_ia, digital_ia, homework_ia, loose_leaf_ia, subscription_ia, pure_ia, non_ia

---

### bookprices_institutional

**Purpose:** Institutional bookstore pricing (sample data)
**Row Count:** 10,795

| Column | Type | Description |
|--------|------|-------------|
| `unit_id` | INTEGER | IPEDS institution identifier |
| `isbn13` | VARCHAR | ISBN-13 |
| `book_status` | VARCHAR | Book status (lowercase) |
| `price` | DECIMAL(10,2) | Price |
| `publisher` | VARCHAR | Publisher name |
| `book_type` | VARCHAR | Book type |

---

### bookprices_publisher

**Purpose:** Publisher list pricing (sample data)
**Row Count:** 606

| Column | Type | Description |
|--------|------|-------------|
| `isbn13` | VARCHAR | ISBN-13 |
| `price` | DECIMAL(10,2) | List price |
| `book_type` | VARCHAR | Book type |
| `publisher` | VARCHAR | Publisher name |

---

### email_issues

**Purpose:** Email quality tracking showing raw vs cleaned emails
**Row Count:** Variable (emails with issues only)

| Column | Type | Description |
|--------|------|-------------|
| `email_raw` | VARCHAR | Original email from source |
| `email_cleaned` | VARCHAR | Cleaned email after processing |
| `source_table` | VARCHAR | Always 'course_catalog' |
| `cleaning_action` | VARCHAR | Type of cleaning applied |

**Cleaning Actions:**
- `extracted_from_text` - Email extracted from "email: addr@domain.com" patterns
- `multiple_emails_took_first` - Multiple emails present, took first one
- `removed_spaces` - Interior spaces removed
- `missing_at_sign` - Email missing @ symbol
- `too_short` - Email too short to be valid
- `other` - Other issues

---

### oer_format_types

**Purpose:** Distinct FormatType values containing "Open Educational Resource"
**Row Count:** Variable (created during import)

| Column | Type | Description |
|--------|------|-------------|
| `FormatType` | VARCHAR | Format type containing OER |
| `record_count` | BIGINT | Number of records with this FormatType |

---

## Comprehensive Data Table

### comprehensive_data

**Purpose:** Merged dataset combining all source data with classifications
**Row Count:** 102,885,609 (same as course_catalog)
**Created By:** 0_setup.sql (initial), 2_oer_classification.sql (final with classifications)

**Includes all columns from:**
- `course_catalog_20251215` (all 27 columns)
- OER/IA classification fields (4 columns)
- IPEDS institutional data (9 columns)
- Panel response data (1 column)
- Opt-out status (2 columns)

**Additional Columns (beyond course_catalog):**

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| `is_oer` | BOOLEAN | format_type_classification | True if material is Open Educational Resource |
| `oer_category` | VARCHAR | format_type_classification | OER category (non_oer if not OER) |
| `is_ia` | BOOLEAN | format_type_classification | True if material is Inclusive Access |
| `ia_category` | VARCHAR | format_type_classification | IA category (non_ia if not IA) |
| `institution_name` | VARCHAR | ipeds_data.instnm | Institution name |
| `sector` | INTEGER | ipeds_data | Sector code |
| `level` | INTEGER | ipeds_data.iclevel | Level code |
| `control` | INTEGER | ipeds_data | Control code |
| `size` | INTEGER | ipeds_data.instsize | Size category |
| `enrollment_2024` | INTEGER | ipeds_data.enroll_24 | Total enrollment 2024 |
| `distance_enrollment_2024` | INTEGER | ipeds_data.dist_enroll_24 | Distance enrollment 2024 |
| `institution_type` | VARCHAR | ipeds_data.inst_type | Institution type |
| `panel_response_year` | VARCHAR | panel | Year of panel response (NULL if none) |
| `is_opted_out` | BOOLEAN | opt_out | True if email opted out |
| `opt_out_source` | VARCHAR | opt_out | Always 'opt_out' when opted out |

**Total Columns:** 42

---

## Views

### master_mailing

**Purpose:** Deduplicated instructor mailing list
**Row Count:** ~1.9M unique emails (excludes opted-out)

**Selection Logic:**
- One row per email address
- DISTINCT ON (email)
- Ordered by: period_sortable DESC, enrollments DESC, RANDOM()
- Excludes NULL/empty emails and opted-out addresses

| Column | Type | Description |
|--------|------|-------------|
| `unit_id` | BIGINT | Institution ID |
| `school` | VARCHAR | School/college |
| `state` | VARCHAR | State code |
| `department` | VARCHAR | Department |
| `course_level` | VARCHAR | Course level |
| `course_subject` | VARCHAR | Subject area |
| `period` | VARCHAR | Term period |
| `period_sortable` | VARCHAR | Sortable period code |
| `instructor` | VARCHAR | Instructor name |
| `first_name` | VARCHAR | First name |
| `last_name` | VARCHAR | Last name |
| `email` | VARCHAR | Email address (unique) |

---

### recent_periods

**Purpose:** Identifies 12 most recent periods (3 years)
**Row Count:** 12

| Column | Type | Description |
|--------|------|-------------|
| `period_sortable` | VARCHAR | Period code (YYYY-N) |

---

### current_mailing

**Purpose:** Current mailing list (last 3 years with panel data)
**Row Count:** ~1.9M

**Includes:** All master_mailing columns plus:

| Column | Type | Description |
|--------|------|-------------|
| `panel_response_year` | VARCHAR | Most recent panel response year (NULL if none) |

**Filter:** Only periods in recent_periods (last 12 periods)

---

### State-Specific Current Mailings

**Purpose:** State-filtered current mailing lists

| View Name | Filter | Approx Records |
|-----------|--------|----------------|
| `current_mailing_ca` | state = 'CA' | ~150K |
| `current_mailing_tx` | state = 'TX' | ~120K |
| `current_mailing_fl` | state = 'FL' | ~80K |
| `current_mailing_ny` | state = 'NY' | ~100K |
| `current_mailing_other` | All other states | ~1.5M |

**All columns same as current_mailing**

---

### Analysis Views (from 4_merged_records.sql)

### faculty_records

**Purpose:** Deduplicated faculty records with course counts
**Deduplication:** DISTINCT ON (email, unit_id, period_sortable)

| Column | Type | Description |
|--------|------|-------------|
| All comprehensive_data columns | | Full dataset |
| `courses_taught` | BIGINT | Count of unique courses taught |

---

### course_section_records

**Purpose:** Unique course sections with enrollment totals
**Deduplication:** DISTINCT ON (section_id, period_sortable)

| Column | Type | Description |
|--------|------|-------------|
| All comprehensive_data columns | | Full dataset |
| `total_enrollment` | BIGINT | Sum of enrollments for section |

---

### course_records

**Purpose:** Unique courses with section counts
**Deduplication:** DISTINCT ON (course_id, period_sortable)

| Column | Type | Description |
|--------|------|-------------|
| All comprehensive_data columns | | Full dataset |
| `sections_offered` | BIGINT | Count of sections for this course |

---

### master_section

**Purpose:** Section-level aggregation with material and enrollment stats

| Column | Type | Description |
|--------|------|-------------|
| `section_id` | VARCHAR | Section identifier |
| `period_sortable` | VARCHAR | Period code |
| `course_title` | VARCHAR | Course title |
| `instructor` | VARCHAR | Instructor name |
| `email` | VARCHAR | Instructor email |
| `enrollments` | INTEGER | Total enrollments |
| `unique_materials` | BIGINT | Count of distinct ISBNs |
| `required_materials` | BIGINT | Count where book_status = 'Required' |
| `oer_materials` | BIGINT | Count where is_oer = true |
| `ia_materials` | BIGINT | Count where is_ia = true |

---

### master_course

**Purpose:** Course-level aggregation across all sections/periods

| Column | Type | Description |
|--------|------|-------------|
| `course_id` | VARCHAR | Course identifier |
| `course_title` | VARCHAR | Course title (most common) |
| `total_sections` | BIGINT | Total sections across all periods |
| `total_enrollments` | BIGINT | Sum of enrollments |
| `unique_materials` | BIGINT | Distinct materials used |
| `periods_offered` | BIGINT | Number of periods offered |
| `instructors` | BIGINT | Distinct instructors |

---

### master_course_material

**Purpose:** Material-level aggregation across all usage

| Column | Type | Description |
|--------|------|-------------|
| `ISBN13` | BIGINT | Material ISBN |
| `Title` | VARCHAR | Material title |
| `Author` | VARCHAR | Author(s) |
| `Publisher` | VARCHAR | Publisher |
| `FormatType` | VARCHAR | Format type |
| `is_oer` | BOOLEAN | Is OER |
| `is_ia` | BOOLEAN | Is IA |
| `times_used` | BIGINT | Number of course adoptions |
| `total_enrollments` | BIGINT | Total student exposure |
| `sections_used` | BIGINT | Distinct sections using material |
| `courses_used` | BIGINT | Distinct courses using material |
| `institutions_used` | BIGINT | Distinct institutions using material |

---

## FormatType Values

**Total Distinct Values:** 69
**Most Common:**

| FormatType | Records | % of Total |
|------------|---------|-----------|
| (empty/NULL) | 64.4M | 62.6% |
| Book | 23.4M | 22.7% |
| eBook | 4.8M | 4.6% |
| Bundle | 2.4M | 2.4% |
| Courseware | 2.4M | 2.4% |
| Loose Leaf | 855K | 0.8% |
| Digital/Inclusive Access/Subscription | 822K | 0.8% |
| Courseware/Homework/Subscription | 784K | 0.8% |
| Courseware/Digital | 756K | 0.7% |

**OER-containing FormatTypes:** 18 types
**IA-containing FormatTypes:** 20 types
**Total OER Records:** 354,809 (0.34%)

---

## Book Status Values

| Value | Records | % of Total |
|-------|---------|-----------|
| (empty/NULL) | 81.6M | 79.3% |
| Required | 17.5M | 17.0% |
| Recommended | 2.1M | 2.1% |
| Option | 1.6M | 1.6% |

---

## Relationships

```
course_catalog_20251215
    ├─[FormatType]─> format_type_classification
    │                   └─> is_oer, oer_category, is_ia, ia_category
    ├─[unit_id]────> ipeds_data
    │                   └─> institution characteristics
    ├─[email]──────> opt_out
    │                   └─> opt-out status
    └─[email]──────> panel
                        └─> response history

comprehensive_data (merge of all above)
    └─> master_mailing (deduplicated instructors)
            └─> current_mailing (recent periods only)
                    ├─> current_mailing_ca (CA only)
                    ├─> current_mailing_tx (TX only)
                    ├─> current_mailing_fl (FL only)
                    ├─> current_mailing_ny (NY only)
                    └─> current_mailing_other (all other states)

comprehensive_data
    ├─> faculty_records (deduplicated faculty)
    ├─> course_section_records (unique sections)
    ├─> course_records (unique courses)
    ├─> master_section (section aggregations)
    ├─> master_course (course aggregations)
    └─> master_course_material (material aggregations)
```

---

## Data Quality Notes

### Email Cleaning
- Emails normalized to lowercase and trimmed
- Extracts emails from "email: addr@domain.com" patterns
- Handles multiple emails (takes first)
- Removes interior spaces
- See `email_issues` table for problematic cases

### OER Identification
- **Method:** Explicit FormatType classification via lookup table
- **Not used:** Publisher-based guessing (removed as unreliable)
- **Accuracy:** 354,809 OER records identified (0.34% of total)

### State Codes
- Two-letter state abbreviations (e.g., CA, TX, FL, NY)
- Source: Original State column from Discovery extract
- **Not derived** from institution name patterns

### Period Codes
- Sortable format: YYYY-N where N=1 (Winter), 2 (Spring), 3 (Summer), 4 (Fall)
- Example: "Fall 2024" → "2024-4"
- NULL if period format doesn't match expected pattern

---

## Key Statistics

- **Total Course Catalog Records:** 102,885,609
- **Unique Institutions:** ~7,000
- **Unique Instructors (emails):** ~1.9M (after opt-outs)
- **Unique Courses:** ~31M
- **Unique Sections:** ~75M
- **OER Records:** 354,809 (0.34%)
- **Required Materials:** 17.5M (17.0%)
- **Opted Out:** Variable (filtered from mailings)
- **Panel Responses:** Variable

---

## File Execution Order

1. **0_setup.sql** - Import raw data, create course_catalog and comprehensive_data
2. **1_bookprices_import.sql** - Import bookprices sample data (optional)
3. **2_oer_classification.sql** - Add OER/IA classification via lookup table
4. **3_mailing_lists.sql** - Create mailing list views
5. **4_merged_records.sql** - Create analysis views (faculty, course, section, master aggregations)

---

## Export Scripts

Located in `scripts/sql/exports/`:

| Export | Source View | Description |
|--------|------------|-------------|
| 01_sample_records | comprehensive_data | 10K sample records |
| 05_email_issues | email_issues | Email cleaning quality check |
| 10_master_mailing | master_mailing | Full deduplicated mailing list |
| 11_current_mailing | current_mailing | Current mailing (last 3 years) |
| 11_recent_mailing | current_mailing | Same as current_mailing |
| 20_california_mailing | current_mailing_ca | CA instructors |
| 21_texas_mailing | current_mailing_tx | TX instructors |
| 22_florida_mailing | current_mailing_fl | FL instructors |
| 23_newyork_mailing | current_mailing_ny | NY instructors |
| 24_texas_fall_series | current_mailing_tx | TX Fall semesters only |
| 30_faculty_records | faculty_records | Deduplicated faculty |
| 31_course_section_records | course_section_records | Unique sections |
| 32_course_records | course_records | Unique courses |
| 33_master_section | master_section | Section aggregations |
| 34_master_course | master_course | Course aggregations |
| 35_master_course_material | master_course_material | Material aggregations |

---

## Database Performance

**Import Time:** ~17-18 minutes (102.9M records)
**Export Time:** ~11 minutes (all 16 exports, 47GB total)
**Database Size:** 45GB (DuckDB file)
**Indexes:** 5 indexes on course_catalog for common queries

**Optimizations:**
- Indexes on email, unit_id, period_sortable, course_id, section_id
- Streaming buffer: 1GB
- Progress bars enabled
- Temp directory: ./tmp
- Insertion order not preserved (better compression)
