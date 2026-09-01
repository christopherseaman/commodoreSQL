-- Export New York mailing list
SELECT *
FROM current_mailing
WHERE UPPER(TRIM(state)) = 'NY';
