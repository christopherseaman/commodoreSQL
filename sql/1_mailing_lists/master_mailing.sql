-- Create master mailing list
-- Filter out opt-out records and records with no email
-- Deduplicate by email using priority rules

CREATE TABLE IF NOT EXISTS master_mailing AS
WITH ranked_records AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY "E-Mail" 
            ORDER BY 
                period_sortable DESC,  -- Most recent date first
                "Enrollment" DESC,     -- Largest enrollment next
                RANDOM()               -- Random selection for ties
        ) AS rank
    FROM comprehensive_data
    WHERE 
        "E-Mail" IS NOT NULL AND 
        "E-Mail" != '' AND
        is_opted_out = 0
)
SELECT * EXCEPT(rank, is_opted_out, opt_out_source)
FROM ranked_records
WHERE rank = 1;
