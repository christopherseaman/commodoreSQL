-- name: Master ISBN dataset — Fall 2025 (material-listing distribution)
-- display: table
-- description: BMG task #37. One record per unique (ISBN13, Title, Author, Format, FormatType) across ALL raw Fall-2025 (period 2025-4) catalog rows — built to reveal how the same/similar material is listed multiple ways so the team can decide whether to combine listings. Missing-ISBN rows are INCLUDED as their own combos (blank source cells import as NULL, ~54% of catalog). This broad raw-listing audit includes NoUse/Canada rows and does not apply the canonical #58 Use filter; supplies are surfaced, not excluded. Counts per combo: NumReq/NumOpt/NumRec/NumBlnk by explicit book_status; NumBVAReq = BVA logic (is_required_inferred, inferred-required #1); NumTot = all rows. NumReq+NumOpt+NumRec+NumBlnk = NumTot by construction. First-non-blank Publisher & Imprint (from catalog) and Edition (from pricing_historical, per-ISBN; ~67% of priced ISBNs, blank for missing-ISBN combos). PublishedYear is not present in the source data (omitted). ~348,826 records; Metabase shows 2,000, full set exportable. Ordered by NumTot desc (most-listed first); re-sort by ISBN13 to cluster listing variants.
WITH ed AS (
    -- first non-blank edition per ISBN13, from the pricing side (catalog has no edition)
    SELECT isbn13, MIN(edition) FILTER (WHERE edition IS NOT NULL AND edition <> '') AS edition
    FROM pricing_historical
    WHERE period_sortable = '2025-4' AND isbn13 IS NOT NULL AND isbn13 <> ''
    GROUP BY isbn13
)
SELECT
    c."ISBN13", c."Title", c."Author", c."Format", c."FormatType",
    COUNT(*) FILTER (WHERE c.book_status = 'required')                     AS NumReq,
    COUNT(*) FILTER (WHERE c.book_status = 'option')                       AS NumOpt,
    COUNT(*) FILTER (WHERE c.book_status = 'recommended')                  AS NumRec,
    COUNT(*) FILTER (WHERE c.book_status IS NULL OR c.book_status = '')    AS NumBlnk,
    COUNT(*) FILTER (WHERE c.is_required_inferred)                              AS NumBVAReq,
    COUNT(*)                                                              AS NumTot,
    COALESCE(BOOL_OR(c.is_supply), FALSE)                                AS IsSupply,
    MIN(c."Publisher") FILTER (WHERE c."Publisher" IS NOT NULL AND c."Publisher" <> '') AS Publisher,
    MIN(c."Imprint")   FILTER (WHERE c."Imprint"   IS NOT NULL AND c."Imprint"   <> '') AS Imprint,
    ANY_VALUE(ed.edition)                                                 AS Edition
FROM comprehensive_data c
LEFT JOIN ed ON c."ISBN13" = ed.isbn13
WHERE c.period_sortable = '2025-4'
GROUP BY c."ISBN13", c."Title", c."Author", c."Format", c."FormatType"
ORDER BY NumTot DESC
