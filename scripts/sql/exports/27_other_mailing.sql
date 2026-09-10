-- Export residual mailing list, including blank and NULL states
SELECT *
FROM current_mailing
WHERE COALESCE(UPPER(TRIM(state)), '')
      NOT IN ('CA', 'TX', 'FL', 'NY', 'PA', 'CAN');
