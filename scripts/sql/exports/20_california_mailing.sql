-- Export California mailing list
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'CA';
