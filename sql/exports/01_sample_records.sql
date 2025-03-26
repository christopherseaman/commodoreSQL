-- Sample records for inspection with explicit column selection
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
    
    -- Time information
    "Period",
    "period_sortable",
    
    -- IPEDS information
    "instnm",
    "sector",
    "iclevel",
    "control",
    "instsize",
    
    -- Book information
    "ISBN13",
    "Title",
    "Author",
    "Publisher",
    "Imprint",
    "Edition",
    "Published Year",
    "Format",
    "FormatType",
    
    -- Detailed institutional information
    "IPED ID",
    "SchoolYearType",
    "Dept Code",
    "Dept Description",
    "Course Level",
    "Course Subject",
    
    -- Detailed course information
    "Seats Taken",
    "Book Status",
    
    -- Detailed IPEDS information
    "efydetot_tot_22",
    "efyde_tot_22",
    "typeinst",
    "insttype",
    
    -- Opt-out information
    "is_opted_out",
    "opt_out_source"
    
FROM comprehensive_data
ORDER BY RANDOM()
LIMIT 10000;
