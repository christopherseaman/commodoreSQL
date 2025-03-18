# Overall plan

1. Create CSV versions of key mailing lists for immediate use.
2. Create merged records by faculty member and by course.
3. Create CSV versions of key merged records.
4. Save all code in a format that can easily be run for each master file update (typically four times a year)
5. Build Graphic User Interface version of database/SQL for ongoing work (can be on any platform - PC / Mac / Unix)
    
## Create CSV versions of key mailing lists for immediate use.

### Sample records for inspection
Extract 10,000 records in CVS format, random or most recent
 
### Build a comprehensive database.
+ All records from CSV file
+ Merge Opt-Out code by email address (Master_optOut.csv)
+ Merge IPEDS data fields (hdic_dist_2022_selected.csv) by IPEDS id
+ Create a new date field (format YYYY-N where YYYY is year and N is 1 to 4 for Winter, Spring, Summer, and Fall)
 
### Create a master mailing list from the Comprehensive Database
+ Omit all records with entry from Master_optOut
+ Omit all records with no email address
+ Retain only one record for each email address using the following priority order:
- Most recent using the newly created date field
- If multiple for same date, then largest "Enrollment"
- If multiple (or missing) enrollment, the randomly selected
 
### Create subset mailing lists in CSV from the master mailing
+ All records from the most recent 8 date periods (covers two year period)
+ All records from the most recent 8 date periods from California
+ All records from the most recent 8 date periods from Texas
+ All records from the most recent 8 date periods from Florida
+ All records from the most recent 8 date periods from New York
 
### Create a Texas time series
Select from the Comprehensive database all records for the state of Texas and a Fall term in any year. Create CVS version.

## Create merged records by faculty member and by course.

### Determine the format for the master faculty record and create a master faculty database.
Create a unique record for each faculty member.
Selected by email address
If there is no email, then select by full name within the institution
Create an indicator on the master faculty record for the number of records being merged, by date - total records for faculty that faculty member for each data period and total number of unique course sections for that faculty member for each time period.

### Determine the format for the master course section record and create a master course section database.
Create a unique record for each course section:
Selected by the course number, section number, and the course title within each institution with each date period
Create an indicator on the master course record for the number of records being merged by date - add fields listing each publisher contained on any of the merged records, up to a maximum of six.

### Determine the format for the master course record and create a master course database.
Combine all sections of a particular course into a single record for each institution and date period.
Create an indicator on the master course record for the number of sections being merged, create a total enrollment variable summing all section enrollments for that course, and add fields listing each publisher on any merged records, up to a maximum of six.


