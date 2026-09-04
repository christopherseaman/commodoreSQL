-- name: Master ISBN — listing variability (Fall 2025)
-- display: table
-- description: All raw Fall-2025 ISBN-bearing catalog rows; no Use/supply filter. Issue #45 finding over all raw Fall-2025 comprehensive_data rows with non-null ISBN13 (no canonical #58 Use or is_supply filter). ISBN13 is a CLEAN KEY — of ~348,825 distinct non-null ISBN13s, ZERO carry more than one distinct Title/Author/Format/FormatType (isbn13_with_multi_* all 0; also serves as a re-runnable DQ guardrail — a future refresh introducing ISBN13-side variability would make these nonzero). So the "same book listed many ways" concern from the original #37 email is NOT at the ISBN13 level, and an ISBN13-keyed "blessed value" correction (as literally scoped in #45) is a no-op. The real variability is one level up: the same Title spans MANY distinct ISBN13s (editions/formats/printings) — ~32,088 titles carry >1 ISBN13, up to 137 ISBN13s for a single title. See card 62 for the title-cluster candidates. Blank-ISBN rows (~54% of catalog) can't be keyed by ISBN13 and are excluded.
WITH by_isbn AS (
    SELECT "ISBN13",
        COUNT(DISTINCT "Title")      AS nt,
        COUNT(DISTINCT "Author")     AS na,
        COUNT(DISTINCT "Format")     AS nf,
        COUNT(DISTINCT "FormatType") AS nft
    FROM comprehensive_data
    WHERE period_sortable = '2025-4' AND "ISBN13" IS NOT NULL
    GROUP BY "ISBN13"
),
by_title AS (
    SELECT "Title", COUNT(DISTINCT "ISBN13") AS ni
    FROM comprehensive_data
    WHERE period_sortable = '2025-4' AND "ISBN13" IS NOT NULL AND "Title" IS NOT NULL
    GROUP BY "Title"
)
SELECT
    (SELECT COUNT(*) FROM by_isbn)                                 AS distinct_isbn13,
    (SELECT COUNT(*) FILTER (WHERE nt > 1) FROM by_isbn)           AS isbn13_with_multi_title,
    (SELECT COUNT(*) FILTER (WHERE na > 1) FROM by_isbn)           AS isbn13_with_multi_author,
    (SELECT COUNT(*) FILTER (WHERE nf > 1 OR nft > 1) FROM by_isbn) AS isbn13_with_multi_format,
    (SELECT COUNT(*) FROM by_title)                               AS distinct_titles,
    (SELECT COUNT(*) FILTER (WHERE ni > 1) FROM by_title)         AS titles_with_multiple_isbn13,
    (SELECT MAX(ni) FROM by_title)                               AS max_isbn13_per_title
