# CommodoreSQL

> **IMPORTANT NOTE:** During development and testing:
> - Database backup functionality is disabled to improve performance
> - The database is deleted at the start of each run for a clean slate
> 
> Before using in production:
> - Re-enable the backup code in `scripts/run_all.sh` by uncommenting the backup and restore sections
> - Consider disabling the database deletion code if you want to preserve data between runs

## Setup and Usage

### Initial Setup

1. Create required directories:
   ```bash
   mkdir -p csv output tmp
   ```

2. Place your CSV files in the `csv` directory:
   - Survey data: `csv/Bayview.YYYYMMDD.csv` (where YYYYMMDD is the date)
   - IPEDS data: `csv/hdic_dist_2022_selected.csv`
   - Opt-out data: `csv/Master_optOut.csv`

3. Make all scripts executable:
   ```bash
   chmod +x scripts/*.sh
   ```

### Running the Pipeline

To run the entire pipeline:
```bash
./scripts/run_all.sh [CSV_DATE]
```

For example:
```bash
./scripts/run_all.sh 20240612
```

If no CSV_DATE is provided, it will use the default from `dot.env`.

### For the Next Data Update

1. Update the CSV_DATE in `dot.env` or provide it as an argument:
   ```bash
   # Example: Update for September 2024 data
   ./scripts/run_all.sh 20240915
   ```

2. Alternatively, edit the `dot.env` file to update the CSV_DATE:
   ```bash
   # Change this line in dot.env
   CSV_DATE="20240915"  # Format: YYYYMMDD
   ```

### Running Individual Steps

You can run each step individually:

```bash
# Step 0: Setup, import, and join data
./scripts/0_setup.sh [CSV_DATE]

# Step 1: Create CSV versions of key mailing lists
./scripts/1_mailing_lists.sh

# Step 2: Create merged records by faculty member and by course
./scripts/2_merged_records.sh

# Step 3: Create CSV versions of key merged records
./scripts/3_export_csv.sh
```

## Project Structure

### Directory Structure

```
commodoreSQL/
├── csv/                  # Input CSV files
├── sql/                  # SQL files for each operation
│   ├── 0_setup/          # Setup and import SQL files
│   │   ├── config.sql                # DuckDB configuration settings
│   │   ├── import.sql                # Import CSV files and create views
│   │   ├── describe_import.sql       # Validate imported data
│   │   ├── comprehensive.sql         # Join data and create comprehensive database
│   │   └── describe_comprehensive.sql # Validate comprehensive database
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
    ├── import_description.txt        # Description of imported data
    └── comprehensive_description.txt # Description of comprehensive database
```

### Configuration

The project uses a `dot.env` file for configuration:

```bash
# Database path
MAIN_DB="commodore.db"

# CSV input files - use variables for date-based filenames
CSV_DATE="20240612"  # Format: YYYYMMDD - update for each import
SURVEY_CSV="csv/Bayview.${CSV_DATE}.csv"
IPEDS_CSV="csv/hdic_dist_2022_selected.csv"
OPTOUT_CSV="csv/Master_optOut.csv"

# Output directory
OUTPUT_DIR="output"

# Performance settings
MEM_LIMIT="16GB"
NUM_THREADS=8

# DuckDB executable path
DUCKDB="./duckdb"  # Path to DuckDB executable

# Debug settings
DEBUG=false        # Set to true to describe at the end
DEBUG_VERBOSE=false # Set to true to describe at each step
```

### Table and View Structure

The project uses a combination of versioned tables and unversioned views:

1. **Versioned Tables**: Tables are named after the CSV files (with lowercase names, no extension, periods replaced with underscores)
   - Example: `bayview_20241211` for the survey data from December 11, 2024
   - Example: `hdic_dist_2022_selected` for the IPEDS data
   - Example: `master_optout` for the opt-out data

2. **Unversioned Views**: Views provide consistent access to the latest data
   - `survey_data` - Always points to the latest survey data
   - `ipeds_data` - Always points to the latest IPEDS data
   - `optout_data` - Always points to the latest opt-out data

This approach allows you to:
- Keep historical data in versioned tables
- Always access the latest data through consistent view names
- Switch to a new data version by simply updating the CSV_DATE

You can customize the DuckDB executable path by:
1. Editing the `dot.env` file
2. Setting the `DUCKDB` environment variable before running the scripts:
   ```bash
   # Example: Use system-installed DuckDB
   export DUCKDB=duckdb
   ./scripts/run_all.sh
   
   # Example: Use DuckDB from a specific path
   export DUCKDB=/usr/local/bin/duckdb
   ./scripts/run_all.sh
   ```

## Project Plan

This project implements the following steps:

1. Create CSV versions of key mailing lists for immediate use
2. Create merged records by faculty member and by course
3. Create CSV versions of key merged records
4. Save all code in a format that can easily be run for each master file update

For detailed specifications of each step, see `plan.md`.
