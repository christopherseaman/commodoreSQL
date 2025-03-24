# Process Documentation

## Overview
This document describes the data processing pipeline that transforms raw survey data into actionable mailing lists and analysis-ready datasets. The process is implemented using DuckDB and shell scripts, with each step building upon the previous ones.

For detailed information about tables, columns, and relationships, see the [Data Dictionary](data_dictionary.md).

## Database Structure

### Core Tables and Relationships
```mermaid
graph LR
    subgraph "Input Tables"
        S[survey_data]
        I[ipeds_data]
        O[optout_data]
    end
    
    subgraph "Generated Views"
        CD[comprehensive_data]
        RD[recent_data]
        MM[master_mailing]
    end
    
    S --> CD
    I --> CD
    O --> CD
    CD --> RD
    CD --> MM
```

### Join Relationships
```mermaid
graph TD
    subgraph "Survey Data"
        S[survey_data]
        S1[E-Mail]
        S2[IPED ID]
        S3[Period]
    end
    
    subgraph "IPEDS Data"
        I[ipeds_data]
        I1[unitid]
        I2[instnm]
        I3[sector]
    end
    
    subgraph "Opt-out Data"
        O[optout_data]
        O1[Emails]
        O2[Source]
    end
    
    S2 --> I1
    S1 --> O1
```

## Overall Process Flow

```mermaid
graph TD
    A[Input CSVs] --> B[Step 0: Setup & Import]
    B --> C[Step 1: Mailing Lists]
    C --> D[Step 2: Merged Records]
    D --> E[Step 3: Export CSVs]
    
    subgraph "Input Files"
        A1[Survey CSV] --> A
        A2[IPEDS CSV] --> A
        A3[Opt-out CSV] --> A
    end
    
    subgraph "Output Files"
        E1[Master Mailing List] --> E
        E2[Subset Lists] --> E
        E3[Faculty Records] --> E
        E4[Course Records] --> E
    end
```

## Step 0: Setup and Import

### Overview
This step initializes the database and imports all source data. It performs data validation and creates the foundation for all subsequent processing.

### Data Flow and Joins
```mermaid
graph TD
    subgraph "Input Processing"
        S[Survey CSV] --> S1[Import]
        I[IPEDS CSV] --> I1[Import]
        O[Opt-out CSV] --> O1[Import]
    end
    
    subgraph "Data Validation"
        S1 --> V1[Validate Periods]
        S1 --> V2[Validate Emails]
        S1 --> V3[Check IPEDS IDs]
    end
    
    subgraph "View Creation"
        V1 --> CD[comprehensive_data]
        V2 --> CD
        V3 --> CD
        I1 --> CD
        O1 --> CD
        CD --> RD[recent_data]
    end
    
    subgraph "Join Logic"
        direction LR
        J1[survey_data] --> J2[LEFT JOIN ipeds_data]
        J2 --> J3[LEFT JOIN optout_data]
        J3 --> J4[Create Views]
    end
```

### Key Operations
1. **Configuration**
   - Set up DuckDB with appropriate memory limits
   - Configure thread count for parallel processing

2. **Data Import**
   - Import survey data from CSV
   - Import IPEDS institutional data
   - Import opt-out list

3. **Data Validation**
   - Validate period formats
   - Check email addresses
   - Verify IPEDS IDs
   - Log invalid records

4. **View Creation**
   - Create comprehensive_data view
   - Create recent_data view
   - Create invalid_periods table

## Step 1: Mailing Lists

### Overview
This step creates the primary mailing lists by deduplicating records and applying opt-out filters.

### Data Flow and Deduplication
```mermaid
graph TD
    subgraph "Input"
        CD[comprehensive_data]
    end
    
    subgraph "Filtering"
        CD --> F1[Remove Opt-outs]
        F1 --> F2[Remove Invalid Emails]
    end
    
    subgraph "Deduplication Logic"
        F2 --> D1[Sort by Period]
        D1 --> D2[Sort by Enrollment]
        D2 --> D3[Random for Ties]
    end
    
    subgraph "Output"
        D3 --> MM[master_mailing]
        D3 --> SL[subset_lists]
    end
```

### Key Operations
1. **Record Filtering**
   - Remove opted-out records
   - Remove records with invalid emails
   - Apply any additional filters

2. **Deduplication**
   - Sort by recency (most recent first)
   - Sort by enrollment size
   - Use random selection for ties

3. **List Creation**
   - Create master mailing list
   - Create subset lists based on criteria

## Step 2: Merged Records

### Overview
This step creates consolidated records by faculty member and course, enabling analysis at different levels.

### Data Flow and Aggregation
```mermaid
graph TD
    subgraph "Input"
        CD[comprehensive_data]
    end
    
    subgraph "Faculty Records"
        CD --> F1[Group by Email]
        F1 --> F2[Latest Info]
        F2 --> F3[Calculate Stats]
    end
    
    subgraph "Course Records"
        CD --> C1[Group by Course]
        C1 --> C2[Aggregate Data]
        C2 --> C3[Calculate Metrics]
    end
    
    subgraph "Section Records"
        CD --> S1[Unique Sections]
        S1 --> S2[Section Stats]
    end
```

### Key Operations
1. **Faculty Records**
   - Group records by email
   - Select latest information
   - Calculate faculty-level statistics

2. **Course Records**
   - Group by course identifier
   - Aggregate enrollment data
   - Calculate course-level metrics

3. **Section Records**
   - Create unique section records
   - Calculate section-level statistics

## Step 3: Export CSVs

### Overview
This step exports the processed data into CSV files for various uses.

### Data Flow and Export
```mermaid
graph TD
    subgraph "Input Sources"
        MM[master_mailing]
        FR[faculty_records]
        CR[course_records]
        SR[section_records]
    end
    
    subgraph "Data Preparation"
        MM --> P1[Select Fields]
        FR --> P1
        CR --> P1
        SR --> P1
        P1 --> P2[Apply Filters]
    end
    
    subgraph "Field Formatting"
        P2 --> F1[Standardize Dates]
        F1 --> F2[Format Numbers]
        F2 --> F3[Clean Text]
    end
    
    subgraph "Export"
        F3 --> E1[Write CSVs]
        E1 --> E2[Validate Output]
    end
```

### Key Operations
1. **Data Preparation**
   - Select required fields
   - Apply final filters
   - Sort records

2. **Field Formatting**
   - Standardize date formats
   - Format numeric fields
   - Clean text fields

3. **Export**
   - Write CSV files
   - Validate output files
   - Create checksums

## Running the Pipeline

### Command Line Usage
```bash
# Run entire pipeline
./scripts/run_all.sh [CSV_DATE]

# Run individual steps
./scripts/0_setup.sh [CSV_DATE]
./scripts/1_mailing_lists.sh
./scripts/2_merged_records.sh
./scripts/3_export_csv.sh
```

### Configuration
The pipeline is configured through the `dot.env` file. Key settings include:
- Database path
- CSV file paths
- Memory limits
- Thread count
- Debug settings

For detailed configuration options, see the [README](../README.md).

### Output Files
All output files are stored in the `output` directory:
- Mailing lists
- Merged records
- Export files
- Log files

For a complete list of output files and their formats, see the [Data Dictionary](data_dictionary.md). 