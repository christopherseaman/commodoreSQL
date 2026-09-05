-- Shared rolling catalog-term window for canonical materials and mailing.
-- Terms are ordered by sortable catalog identifier; NULL identifiers never enter.

${CONFIG}

DROP VIEW IF EXISTS recent_period;
CREATE VIEW recent_period AS
SELECT DISTINCT period_sortable
FROM ${SURVEY_TABLE}
WHERE period_sortable IS NOT NULL
ORDER BY period_sortable DESC
LIMIT 12;

SELECT 'recent catalog terms' AS metric, COUNT(*) AS term_count
FROM recent_period;
