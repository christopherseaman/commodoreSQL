-- Export random sample of comprehensive records
SELECT *
FROM comprehensive_data
ORDER BY RANDOM()
LIMIT 10000;
