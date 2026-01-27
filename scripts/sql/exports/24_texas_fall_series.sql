-- Export Texas Fall mailing series
SELECT *
FROM current_mailing_tx
WHERE period LIKE 'Fall%'
ORDER BY period_sortable DESC;
