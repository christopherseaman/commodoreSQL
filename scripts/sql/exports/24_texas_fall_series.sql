-- Export Texas Fall mailing series
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'TX'
  AND period LIKE 'Fall%'
ORDER BY period_sortable DESC;
