-- Texas fall series with explicit column selection
-- Note: Unlike the mailing lists, this view is NOT deduplicated by email address.
-- It includes ALL records from Texas that are from Fall terms, potentially multiple per email.
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
    
    -- Time information (includes all Fall periods for each email)
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
    
FROM texas_fall_series;
