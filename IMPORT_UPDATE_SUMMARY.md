# CommodoreSQL Import Logic Update Summary

## Overview
Updated the DuckDB import pipeline to work with the latest 2025.12.15 dataset and incorporate new requirements from meeting documentation.

## Changes Made

### 1. Environment Configuration (`docker/scripts/dot.env`)
**Updated** to point to new data sources and reflect modern naming conventions:

- **CSV_DATE**: Updated from `20241211` to `20251215`
- **Table Names**:
  - `SURVEY_TABLE`: Changed to `course_catalog_${CSV_DATE}` (was `survey_data_${CSV_DATE}`)
  - `OPTOUT_TABLE`: Renamed to `opt_out` (was `optout_data`)
  - **NEW**: `PANEL_TABLE`: Added for panel response tracking

- **Data Sources**: Updated all paths to `/home/christopher/projects/commodoreSQL/data/2025.12.15/`:
  - `SURVEY_CSV`: DiscoveryExtract.20251215.csv
  - `IPEDS_CSV`: IPEDS_2024.csv
  - `OPTOUT_CSV`: OptOut_20251215.csv
  - **NEW**: `PANEL_CSV`: panel_20260108.csv

### 2. Data Import SQL (`docker/scripts/sql/0_setup.sql`)

#### Schema Changes
**Adopted snake_case naming** for all columns (per meeting notes):
- `"E-Mail"` → `email`
- `"Course Number"` → `course_number`
- `"First Name"` → `first_name`
- All other fields converted to snake_case

#### New Fields Added
- **course_id**: Composite key `school || '|' || department || '|' || course_number`
- **section_id**: Extended course_id with `section`
- **book_status**: Materialized from `"Book Status"` field
- **seats_taken**: Materialized from `"Seats Taken"` field

#### Fields Dropped (Per Meeting Notes)
- Edition
- PublishedYear
- SchoolYearType
- State (use IPEDS instead)
- Dept Code

#### New Data Sources
1. **IPEDS Updates**:
   - Updated field mapping for 2024 IPEDS structure
   - `UNITID`, `INSTNM`, `SECTOR`, `ICLEVEL`, `CONTROL`, `INSTSIZE`
   - New enrollment fields: `Enroll_24`, `DistEnroll_24`
   - `InstType` (was `typeinst`/`insttype`)

2. **Panel Data** (NEW):
   - Tracks survey responses by email and year
   - Fields: `email`, `response_year`
   - Joined to comprehensive_data

3. **Email Quality Check** (NEW):
   - `email_issues` table identifies problematic emails
   - Checks for interior spaces, empty values across all source tables
   - Includes source table tracking

#### Comprehensive Data Merge
**Updated join logic** to include:
- IPEDS join on `unit_id = unitid`
- Opt-out join on normalized email
- **NEW**: Panel join on email to include `panel_response_year`

### 3. Mailing Lists (`docker/scripts/sql/1_mailing_lists.sql`)

#### Views Renamed
- `recent_mailing` → `current_mailing`
- State-specific mailings now use `current_mailing_*` prefix:
  - `current_mailing_ca`, `current_mailing_tx`, `current_mailing_fl`, `current_mailing_ny`
  - **NEW**: `current_mailing_other`

#### Enhanced Features
- **Extended time window**: Now includes 12 periods (3 years) instead of 8
- **Panel integration**: `current_mailing` includes `panel_response_year`
- **Improved state filtering**: Uses IPEDS institution names instead of deprecated State field
- All mailings exclude opted-out emails

### 4. Course Analysis (`docker/scripts/sql/2_merged_records.sql`)

#### New Views for Course-Level Analysis

1. **master_section** (NEW):
   - One row per `section_id` per `period`
   - Material distribution metrics:
     - `material_count`, `required_count`, `optional_count`
     - `publishers`, `required_publishers`
     - `required_publisher_count`, `optional_publisher_count`
   - Enrollment data: `enrollments`, `seats_taken`

2. **master_course** (NEW):
   - One row per `course_id` per `period`
   - Aggregated from `master_section`
   - Metrics:
     - `section_count`
     - `enrollment_total`, `seats_taken_total`
     - `total_materials`, `total_required`, `total_optional`
     - `unique_required_publishers`

3. **master_course_material** (NEW):
   - Material distribution by course and publisher
   - Tracks `book_status` (required/optional)
   - Metrics:
     - `material_instances`
     - `sections_using`
     - `total_seats_affected`

#### Legacy Compatibility
- `course_section_records` and `course_records` maintained as views
- Map to new `master_section` and `master_course` structures

### 5. Export Definitions

#### Updated Exports
- `10_master_mailing.sql`: Updated to use snake_case fields
- `11_current_mailing.sql`: Renamed from `recent_mailing`, includes `panel_response_year`

#### New Exports
- `05_email_issues.sql`: Email quality check report
- `33_master_section.sql`: Section-level material distribution
- `34_master_course.sql`: Course-level aggregated analysis
- `35_master_course_material.sql`: Publisher distribution by course

## Data Schema Summary

### Core Tables
1. **course_catalog_20251215**: Raw course/material data with derived fields
2. **ipeds_data**: Institutional characteristics
3. **opt_out**: Opt-out email list
4. **panel**: Survey response tracking
5. **email_issues**: Data quality monitoring

### Primary Views
1. **comprehensive_data**: Merged view of all sources
2. **master_mailing**: Deduplicated contact list
3. **current_mailing**: Last 3 years with panel data
4. **master_section**: Section-level material analysis
5. **master_course**: Course-level aggregations
6. **master_course_material**: Publisher distribution

### Derived IDs
- **course_id**: `school|department|course_number`
- **section_id**: `school|department|course_number|section`
- **faculty_id**: `email` or `instructor_school` composite

## Key Improvements

1. **Consistent naming**: All fields use snake_case
2. **Better normalization**: Derived IDs enable proper foreign key relationships
3. **Enhanced analytics**: Course and section-level material tracking
4. **Panel integration**: Tracks survey response history
5. **Data quality**: Email validation and issue tracking
6. **Flexible exports**: New granular export options for different analysis needs

## Running the Import

```bash
cd /home/christopher/projects/commodoreSQL/docker/scripts
./run.sh
```

The pipeline will:
1. Load all CSV files (course catalog, IPEDS, opt-out, panel)
2. Normalize and merge data
3. Create all derived views
4. Generate exports (unless NO_EXPORT=1)

## Import Success Verification

**Status**: ✅ Successfully completed on 2026-01-19

### Database Statistics
| Metric | Count |
|--------|------:|
| Total course records | 102,885,609 |
| Unique emails (master_mailing) | 1,938,886 |
| Current mailing (3yr) | 1,374,912 |
| Panel respondents | 10,896 |
| Email issues found | 753 |
| Unique sections | 75,252,590 |
| Unique courses | 30,883,642 |
| IPEDS institutions | 6,072 |

### Database Objects Created
**Tables (6)**:
- `course_catalog_20251215` - Raw course/material data
- `comprehensive_data` - Merged view with all sources
- `ipeds_data` - Institutional characteristics
- `opt_out` - Opt-out list
- `panel` - Survey responses
- `email_issues` - Data quality checks

**Views (14)**:
- `master_mailing` - Deduplicated contacts
- `current_mailing` - Last 3 years with panel data
- `current_mailing_ca/tx/fl/ny/other` - State-specific mailings
- `master_section` - Section-level material analysis
- `master_course` - Course-level aggregations
- `master_course_material` - Publisher distribution
- `faculty_records` - Faculty aggregations
- `course_records`, `course_section_records` - Legacy compatibility
- `recent_periods` - Time window helper

### Import Performance
- **Duration**: ~17 minutes (0_setup.sql)
- **Database Size**: 33GB
- **Peak Memory**: ~29GB
- **Source Data**: 29GB CSV file

### Data Quality Notes
- **Email Issues**: 753 problematic email addresses identified (spaces, malformed)
- **Panel Integration**: 7,867 emails matched with survey response data
- **Opt-out Filtering**: 103,412 opt-out emails excluded from mailing lists

## Next Steps

1. **Validation**: Review email_issues table for data quality
2. **Sample checks**: Verify 1000-row snapshots from each major view
3. **Categorical comparison**: Check for new/unexpected categories in key fields
4. **Superset integration**: Update Superset dataset definitions for new views
5. **Documentation**: Create data dictionary for new fields and views

## Notes

- Import process can take significant time with large datasets (29GB CSV)
- DuckDB will use substantial memory (expect 20-30GB) during import
- All previous table/view names maintained for backward compatibility where possible
- New field structure aligns with meeting documentation requirements (26.01.08.md, 25.06.24.md)
