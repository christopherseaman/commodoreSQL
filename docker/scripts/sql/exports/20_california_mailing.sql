-- California mailing list with explicit column selection
-- Note: For each email address, this contains the record with the most recent period.
-- If there are multiple records with the same email and period, the one with the largest enrollment is selected.
-- This view only includes records from California and from the 8 most recent periods.
SELECT
    -- Primary contact information
    "E-Mail",
    "Instructor",
    "FirstName",
    "LastName",
    
    -- Institution information
    "School",
    "Department",
    "State",
    
    -- Course information
    "Course Number",
    "Section",
    "Course Title",
    "Enrollments",
    
    -- Time information (contains the most recent period for each email)
    "Period",
    "period_sortable",
    
    -- IPEDS information
    "instnm",
    "sector",
    "iclevel",
    "control",
    "instsize",
    
    -- Less commonly used fields (commented out to reduce export size)
    -- Book information
    -- "ISBN13",
    -- "Title",
    -- "Author",
    -- "Publisher",
    -- "Imprint",
    -- "Edition",
    -- "Published Year",
    -- "Format",
    -- "FormatType",
    
    -- Detailed institutional information
    -- "IPED ID",
    -- "SchoolYearType",
    -- "Dept Code",
    -- "Dept Description",
    -- "Course Level",
    -- "Course Subject",
    
    -- Detailed course information
    -- "Seats Taken",
    -- "Book Status",
    
    -- Detailed IPEDS information
    -- "efydetot_tot_22",
    -- "efyde_tot_22",
    -- "typeinst",
    -- "insttype",
    
    -- Opt-out information (already filtered out in the view)
    -- "is_opted_out",
    -- "opt_out_source"
    
FROM california_mailing
