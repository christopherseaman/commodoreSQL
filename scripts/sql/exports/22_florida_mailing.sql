-- Export Florida mailing list
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'FL';
