---
notion-id: f04f0103-b3d1-409a-94f1-adf673830593
---
# Setup
## Description
Basic data base is flat file, 29 columns, 78+ million records.  A sample of N=250 records is attached.
Current stored in an SQLite data base on my Mac using the "DB Browser for SQLite" for viewing, etc.
> [!note]+ ## Schema
> The fields for all records are:
> 
> | Column | Type |
> | --- | --- |
> | ISBN13 | Real |
> | Title | Text |
> | Author | Text |
> | Publisher | Text |
> | Imprint | Text |
> | Edition | Text |
> | Published Year | Text |
> | Format | Text |
> | FormatType | Text |
> | IPEDID | Integer |
> | School | Text |
> | SchoolYearType | Text |
> | State | Text |
> | DeptCode | Text |
> | Department | Text |
> | DeptDescription | Text |
> | CourseNumber | Text |
> | Section | Integer |
> | CourseTitle | Text |
> | CourseLevel | Text |
> | CourseSubject | Text |
> | Period | Text |
> | Enrollments | Integer |
> | Instructor | Text |
> | FirstName | Text |
> | LastName | Text |
> | E-Mail | Text |
> | SeatsTaken | Text |
> | BookStatus | Text |
# Tasks:
> [!tip] 💡
> **Nota Bene** - The following SQL uses `JOIN`s to create new tables. It would also be possible to use `ALTER TABLE` and `UPDATE` to modify/combine table content in-place, which could be more space efficient.

## 1. Sortable `period` variable
> Create new sortable Period variable with year and term:
> - Winter=1
> - Spring=2
> - Summer=3
> - Fall=4
> For example: "Fall 2023" would become "2023-4"

```sql
ALTER TABLE survey_data ADD COLUMN period_sortable TEXT;

UPDATE survey_data
SET period_sortable =
    CASE
        WHEN Period LIKE 'Winter %' THEN substr(Period, -4) || '-1'
        WHEN Period LIKE 'Spring %' THEN substr(Period, -4) || '-2'
        WHEN Period LIKE 'Summer %' THEN substr(Period, -4) || '-3'
        WHEN Period LIKE 'Fall %' THEN substr(Period, -4) || '-4'
    END;
```
The `substr` function in the SQL command is used to extract a substring from the `Period` column. In this specific context:
- `substr(Period, -4)` extracts the last 4 characters of the `Period` string, which represents the year.
- `|| '-1'` concatenates the extracted year with `1`, `2`, `3`, or `4` based on the term (Winter, Spring, Summer, Fall).

## 2. Join `OptOut` code
> Left join to add OptOut code to every record in the database as a new field using the file Opt_out.csv (attached) as the lookup table and E-Mail as the index variable.  There will be multiple records with the same email address - each one of them should have the OptOut text string added.  If there is not a match for a particular email address the OptOut field should be left blank.

```sql
CREATE TABLE survey_data_with_optout AS
SELECT sd.*, opt.OptOut
FROM survey_data sd
LEFT JOIN opt_out opt ON TRIM(LOWER(sd.E_Mail)) = TRIM(LOWER(opt.E_Mail));

```
## 3. `IPEDID` enrichment
> Left join to add 8 selected variables (sector, iclevel, control, instsize, efydetot_tot_22, efyde_tot_22, typeinst, insttype) to every record in the database as a new field using the file hdic_dist_2022_selected.csv (attached) as the lookup table and IPEDID as the index variable.  There will be multiple records with the same IPEDID - each one of them should have the 8 selected variables added.  If there is not a match for a particular IPEDID the 8 selected variables fields should be left blank.

```sql
CREATE TABLE survey_data_with_hdic AS
SELECT sdo.*, hd.sector, hd.iclevel, hd.control, hd.instsize, hd.efydetot_tot_22, hd.efyde_tot_22, hd.typeinst, hd.insttype
FROM survey_data_with_optout sdo
LEFT JOIN hdic_data hd ON sdo.IPEDID = hd.IPEDID;

```
## 4. Subset for latest periods
> Create a new database with a subset of records selected from the master database:
> ```sql
> Select if "Period" = "Spring 2024"
> 				   , "Winter 2024"
> 				   , "Fall 2023"
> 				   , "Summer 2023"
> AND
> E-Mail is not blank
> AND
> OptOut is blank
> Save the resulting database of "Current Working"
> 
> ```
> Alternatively,  use the sortable period column to select the four most recent period given the a particular date variable

For a fixed list of periods:
```sql
CREATE TABLE current_working_db AS
SELECT *
FROM sample_data
WHERE SortablePeriod IN ('2024-2', '2024-1', '2023-4', '2023-3')
  AND E_Mail IS NOT NULL
  AND OptOut IS NULL;

```
For the latest four period prior to a reference_period `ref_period`:
```sql
-- Define the reference period, e.g., '2024-2'
WITH reference_period AS (
    SELECT '2024-2' AS ref_period
),
sorted_periods AS (
    SELECT DISTINCT period_sortable
    FROM survey_data_with_hdic
    ORDER BY period_sortable DESC
),
relevant_periods AS (
    SELECT period_sortable
    FROM sorted_periods, reference_period
    WHERE period_sortable < reference_period.ref_period
    ORDER BY period_sortable DESC
    LIMIT 4
)

CREATE TABLE current_working_db AS
SELECT *
FROM survey_data_with_hdic
WHERE period_sortable IN (SELECT period_sortable FROM relevant_periods)
  AND E_Mail IS NOT NULL
  AND OptOut IS NULL;

```
## 5. Distinct email addresses
> Use the "Current Working" database and select all records containing a unique E-Mail address.  The order for selection for all duplicate E-Mail is by
> - Period: "Spring 2024" then "Fall 2023" then "Winter 2024" then "Summer 2023"
> - Enrollment: Largest to smallest
> 
> If there are duplicates still remaining, then select which ever one is first appearing.
> Save the resulting database as "Current E-Mail"

```sql
CREATE TABLE current_email_db AS
WITH ordered_data AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY E_Mail ORDER BY period_sortable ASC, Enrollments DESC) AS row_num
    FROM current_working_db
)
SELECT *
FROM ordered_data
WHERE row_num = 1;

```
## 6. Split by `OpenStax`
> Divide the "Current E-Mail" file into two files:
> - "Current OpenStax Email": All with the text "OpenStax" included in any position in the Publisher field.
> - "Current General Email": All where the text "OpenStax" in not included in any position in the Publisher field.
> 
> Save both files.

```sql
CREATE TABLE current_openstax_email AS
SELECT *
FROM current_email_db
WHERE Publisher LIKE '%OpenStax%';

CREATE TABLE current_general_email AS
SELECT *
FROM current_email_db
WHERE Publisher NOT LIKE '%OpenStax%';

```
# Tooling
Commentary courtesy of ChatGPT
## DBViewer
Continue using SQLite or other database (DuckDB + Parquet) and perform operations via SQL
> [!note]+ ## Ninox Database
> Understood. Given these constraints, a more appropriate choice would be **Ninox Database**, which provides a very user-friendly, drag-and-drop interface and can be installed locally on a Mac. Here's how to proceed with Ninox Database:
> ### Steps to Use Ninox Database on macOS
> 1. **Download and Install Ninox Database**
>     - Download Ninox from the [Mac App Store](https://apps.apple.com/us/app/ninox-database/id901327153?mt=12).
>     - Install and open the application on your Mac.
> 2. **Import Data into Ninox**
>     - Open Ninox and create a new database.
>     - Import your CSV files (`survey_data`, `Opt_out`, `hdic_dist_2022_selected`) into Ninox by selecting "Import" from the database menu.
> 3. **Create Relationships and Perform Operations**
>     - **Create Relationships**:
>         - After importing, define relationships between tables using the drag-and-drop interface.
>         - For example, link `survey_data` and `Opt_out` tables via the `E-Mail` field, and `survey_data` and `hdic_dist_2022_selected` via the `IPEDID` field.
>         - Normalize emails by creating a calculated field in each table that trims and lowers the email values.
>     - **Add a New Sortable Period Column**:
>         - Create a new field `period_sortable` in the `survey_data` table.
>         - Use Ninox's formula editor to populate this field:
> ```plain text
> if Period contains "Winter" then substr(Period, -4) + "-1"
> else if Period contains "Spring" then substr(Period, -4) + "-2"
> else if Period contains "Summer" then substr(Period, -4) + "-3"
> else if Period contains "Fall" then substr(Period, -4) + "-4"
> 
> ```
>     - **Perform Joins**:
>         - Utilize Ninox's lookup and related fields to display data from `Opt_out` and `hdic_dist_2022_selected` tables in `survey_data`.
> 4. **Filter and Select Data**
>     - Use Ninox's query builder to filter and select data.
>     - For example, to create the `current_working_db` subset:
>         - Create a new view or table.
>         - Apply filters for `period_sortable` within the desired range and ensure `E-Mail` is not null and `OptOut` is null.
> 5. **Deduplicate and Create Specific Tables**
>     - For deduplication based on `E-Mail`:
>         - Create a script or use Ninox's formula editor to select unique emails based on the given criteria.
>     - Create separate tables for `current_openstax_email` and `current_general_email` by applying text filters on the `Publisher` field.
> 
> ### Summary of Operations in Ninox
> - **Import CSV Files**: Import `survey_data`, `Opt_out`, and `hdic_dist_2022_selected`.
> - **Create Relationships**: Define relationships between tables using drag-and-drop.
> - **Add Calculated Fields**: Use the formula editor to create new calculated fields (e.g., `period_sortable`, normalized email).
> - **Filter Data**: Use the query builder to filter and create subsets of data.
> - **Deduplicate**: Use scripts or formulas to ensure unique entries based on email.
> - **Export Results**: Export the filtered and processed data as needed.
> 
> ### Conclusion
> Ninox Database provides an intuitive interface suitable for users with minimal SQL knowledge, allowing them to perform complex database operations through a graphical interface. This ensures compliance with local data storage laws while providing the necessary functionality.
> [!note]+ ## Filemaker Pro
> Using FileMaker Pro for these operations provides a robust and user-friendly environment. Here are the steps to perform the required operations using FileMaker Pro:
> ### Steps to Use FileMaker Pro on macOS
> 1. **Download and Install FileMaker Pro**
>     - Download FileMaker Pro from the [Claris website](https://www.claris.com/filemaker/).
>     - Install and open the application on your Mac.
> 2. **Import Data into FileMaker Pro**
>     - Create a new database in FileMaker Pro.
>     - Import your CSV files (`survey_data`, `Opt_out`, `hdic_dist_2022_selected`) into separate tables in FileMaker Pro by going to `File > Import Records > File...`.
> 3. **Create Relationships and Perform Operations**
>     - **Create Relationships**:
>         - Go to `File > Manage > Database` and switch to the `Relationships` tab.
>         - Create relationships between tables:
>             - `survey_data` and `Opt_out` via the `E-Mail` field.
>             - `survey_data` and `hdic_dist_2022_selected` via the `IPEDID` field.
>         - Ensure you normalize the `E-Mail` field by creating a calculated field that trims and lowers the email values in each table.
> 4. **Add a New Sortable Period Column**
>     - Go to `File > Manage > Database` and switch to the `Fields` tab.
>     - Add a new field `period_sortable` to the `survey_data` table.
>     - Define a calculated value for `period_sortable`:
> ```plain text
> Case (
>   PatternCount(Period; "Winter"); Right(Period; 4) & "-1";
>   PatternCount(Period; "Spring"); Right(Period; 4) & "-2";
>   PatternCount(Period; "Summer"); Right(Period; 4) & "-3";
>   PatternCount(Period; "Fall"); Right(Period; 4) & "-4";
>   ""
> )
> 
> ```
> 5. **Perform Joins**
>     - Use the relationships defined earlier to display related data from `Opt_out` and `hdic_dist_2022_selected` tables in `survey_data`.
>     - Create new fields in `survey_data` to lookup values from the related tables.
> 6. **Create a New Database with a Subset of Records Based on Reference Period**
>     - Define a `reference_period` field in the `survey_data` table to hold the reference period value (e.g., `2024-2`).
>     - Create a script to filter records based on the most recent four periods before the `reference_period`:
> ```plain text
> Go to Layout [ “survey_data” (survey_data) ]
> Enter Find Mode [ ]
> Set Field [ survey_data::period_sortable; "2023-3...2024-2" ]
> Perform Find [ ]
> Constrain Found Set [ Specified criteria: survey_data::E-Mail ≠ "" and survey_data::OptOut = "" ]
> 
> ```
>     - Save the found set as a new table or export the records as needed.
> 7. **Select Records Containing a Unique E-Mail Address**
>     - Create a script to deduplicate records based on `E-Mail`:
> ```plain text
> Go to Layout [ “survey_data” (survey_data) ]
> Sort Records [ Restore; No dialog ]
> Set Variable [ $lastEmail = "" ]
> Loop
>   Set Variable [ $currentEmail = survey_data::E-Mail ]
>   If [ $currentEmail = $lastEmail ]
>     Omit Record
>   Else
>     Set Variable [ $lastEmail = $currentEmail ]
>     Go to Record/Request/Page [ Next; Exit after last ]
>   End If
> End Loop
> 
> ```
>     - Save the resulting found set as a new table or export the records as needed.
> 8. **Divide into Two Files**
>     - Create scripts to filter records into `current_openstax_email` and `current_general_email`:
> ```plain text
> Go to Layout [ “survey_data” (survey_data) ]
> Enter Find Mode [ ]
> Set Field [ survey_data::Publisher; "*OpenStax*" ]
> Perform Find [ ]
> Save Records as Excel [ “Current_OpenStax_Email.xlsx” ]
> 
> Enter Find Mode [ ]
> Set Field [ survey_data::Publisher; "!*OpenStax*" ]
> Perform Find [ ]
> Save Records as Excel [ “Current_General_Email.xlsx” ]
> 
> ```
> 
> ### Summary of Operations in FileMaker Pro
> - **Import CSV Files**: Import `survey_data`, `Opt_out`, and `hdic_dist_2022_selected`.
> - **Create Relationships**: Define relationships between tables using the relationships graph.
> - **Add Calculated Fields**: Use calculated fields to create new fields (e.g., `period_sortable`, normalized email).
> - **Filter Data**: Use scripts to filter and create subsets of data.
> - **Deduplicate**: Use scripts to ensure unique entries based on email.
> - **Export Results**: Export the filtered and processed data as needed.
> 
> ### Conclusion
> FileMaker Pro provides a powerful and user-friendly environment suitable for users with minimal SQL knowledge. It allows complex database operations through a graphical interface and scripting capabilities, ensuring ease of use while maintaining the required functionality.