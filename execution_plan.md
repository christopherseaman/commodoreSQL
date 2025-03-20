# Execution Plan for CommodoreSQL

This plan adapts the existing workflow to:
1. Use DuckDB native database instead of Parquet files
2. Create dedicated SQL files in a sql folder
3. Use variables for CSV filenames with dates

## Validation Against Requirements

This execution plan addresses the requirements specified in plan.md:

1. ✅ Create CSV versions of key mailing lists for immediate use
   - Sample records for inspection (10,000 random records)
   - Comprehensive database with merged data
   - Master mailing list with deduplication
   - Subset mailing lists for recent records and specific states
   - Texas time series for Fall terms

2. ✅ Create merged records by faculty member and by course
   - Faculty records grouped by email or name within institution
   - Course section records with publisher fields
   - Course records with total enrollment and publisher fields

3. ✅ Create CSV versions of key merged records
   - All tables exported to CSV format

4. ✅ Save all code in a format that can easily be run for each master file update
   - Variable-based filenames for quarterly updates
   - Single run_all.sh script to execute the entire workflow

5. ⏳ Build Graphic User Interface version of database/SQL for ongoing work
   - This requirement is noted for future implementation
   - The current execution plan focuses on the data processing pipeline

## Directory Structure

```
commodoreSQL/
├── csv/                  # Input CSV files
├── sql/                  # SQL files for each operation
│   ├── 0_setup/          # Setup and import SQL files
│   ├── 1_mailing_lists/  # Mailing lists SQL files
│   ├── 2_merged_records/ # Merged records SQL files
│   └── 3_export_csv/     # Export SQL files
├── scripts/              # Shell scripts to execute SQL files
│   ├── 0_setup.sh        # Step 0: Setup, import, and join data
│   ├── 1_mailing_lists.sh # Step 1: Create mailing lists
│   ├── 2_merged_records.sh # Step 2: Create merged records
│   ├── 3_export_csv.sh   # Step 3: Export to CSV
│   └── run_all.sh        # Step 4: Run all steps in sequence
├── tmp/                  # Temporary files directory
└── output/               # Output CSV files directory
```

## Configuration

Update `dot.env` file to use variables for date-based filenames:

```bash
# Database path
MAIN_DB="commodore.db"

# CSV input files - use variables for date-based filenames
CSV_DATE="YYYYMMDD"  # Format to be updated for each import
SURVEY_CSV="csv/bayview_${CSV_DATE}.csv"
IPEDS_CSV="csv/hdic_dist_2022_selected.csv"
OPTOUT_CSV="csv/Master_optOut.csv"

# Output directory
OUTPUT_DIR="output"
```

## Execution Flow (Matching plan.md Steps)

### Step 0: Setup, import, and join data
This step handles the initial data import and creates the comprehensive database that serves as the foundation for all subsequent steps.

**Operations:**
- Import CSV files into versioned DuckDB tables
- Create unversioned views for consistent access
- Build comprehensive database by joining survey data with IPEDS and opt-out data
- Create the date field in YYYY-N format (for year and quarter)

**Implementation:**
- Script: `scripts/0_setup.sh`
- SQL files:
  - `sql/0_setup/config.sql`: Configure DuckDB settings (memory, threads, progress bar)
  - `sql/0_setup/import.sql`: Import CSV files and create views
  - `sql/0_setup/describe_import.sql`: Validate imported data structure and content
  - `sql/0_setup/comprehensive.sql`: Join data and create the comprehensive database
  - `sql/0_setup/describe_comprehensive.sql`: Validate comprehensive database structure and joins

**Key Features:**
- Uses versioned tables based on CSV filenames (e.g., `bayview_20241211`)
- Creates unversioned views for consistent access (e.g., `survey_data`)
- Handles CSV files with variable date components
- Properly joins data using appropriate keys
- Includes debugging options:
  - `DEBUG=true`: Generate detailed descriptions at the end
  - `DEBUG_VERBOSE=true`: Generate detailed descriptions at each step

### Step 1: Create CSV versions of key mailing lists for immediate use
This step creates various mailing lists from the comprehensive database.

**Operations:**
- Create master mailing list with deduplication
- Create subset mailing lists for recent records and specific states
- Create Texas time series for Fall terms

**Implementation:**
- Script: `scripts/1_mailing_lists.sh`
- SQL files:
  - `sql/1_mailing_lists/master_mailing.sql`: Create master mailing list
  - `sql/1_mailing_lists/subset_mailings.sql`: Create subset mailing lists

### Step 2: Create merged records by faculty member and by course
This step creates merged records organized by faculty member and by course.

**Operations:**
- Create faculty records grouped by email or name within institution
- Create course section records with publisher fields
- Create course records with total enrollment and publisher fields

**Implementation:**
- Script: `scripts/2_merged_records.sh`
- SQL files:
  - `sql/2_merged_records/faculty_records.sql`: Create faculty records
  - `sql/2_merged_records/course_sections.sql`: Create course section records
  - `sql/2_merged_records/courses.sql`: Create course records

### Step 3: Create CSV versions of key merged records
This step exports all tables to CSV format for external use.

**Operations:**
- Export all tables to CSV format
- Save files to the output directory

**Implementation:**
- Script: `scripts/3_export_csv.sh`
- SQL files:
  - `sql/3_export_csv/export.sql`: Export tables to CSV

### Step 4: Save all code in a format that can easily be run for each master file update
This step provides a single script to run the entire workflow for quarterly updates.

**Operations:**
- Execute all steps in sequence
- Support for variable-based filenames for quarterly updates

**Implementation:**
- Script: `scripts/run_all.sh`
- Features:
  - Accepts CSV_DATE as an argument
  - Makes all scripts executable
  - Runs each step in the correct order
  - Provides clear error messages and status updates

## Implementation Approach

1. **One Script Per Step**: Each step in plan.md has its own dedicated script
   - Clear separation of concerns
   - Easy to run individual steps as needed

2. **SQL Files Separate from Scripts**: All SQL logic is in dedicated SQL files
   - Better maintainability and readability
   - SQL files are organized in directories matching the steps

3. **Variable Handling**: Use environment variables for date-based filenames
   - Update before each quarterly run
   - Example: `CSV_DATE="20240612"` can be changed to `CSV_DATE="20240915"` for the next quarter

4. **Local Temporary Directory**: Use a local tmp/ directory for better portability
   - All project files are contained within the project directory
   - Makes the project easier to move between systems

5. **DuckDB Native**: Use DuckDB's native database format instead of Parquet
   - Store all tables in a single database file
   - Example: `MAIN_DB="commodore.db"`
