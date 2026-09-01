-- name: Coverage & Scope — Canonical Use Pricing by Term
-- display: table
-- description: Current-snapshot pricing and classification coverage over canonical material_costs Use items (one period × section × ISBN). inferred_required_item_count uses catalog is_required_inferred; inferred_optional_item_count is its complement. item_count is the percentage denominator; section/course/institution/ISBN columns are distinct canonical denominators. has_pricing_match records exact source-key presence, while valid_price_item_count requires non-NULL price_min after the <9999 rule (zero remains valid), so matched_without_valid_price is kept separate. Option presence is independent of valid price and price_avg is not used.

SELECT
    period_sortable,
    COUNT(*) AS item_count,
    COUNT(DISTINCT section_id) AS section_count,
    COUNT(DISTINCT course_id) AS course_count,
    COUNT(DISTINCT unit_id) AS institution_count,
    COUNT(DISTINCT isbn13) AS isbn_count,
    COUNT(*) FILTER (WHERE has_pricing_match) AS pricing_match_item_count,
    COUNT(*) FILTER (WHERE NOT has_pricing_match) AS unmatched_item_count,
    COUNT(*) FILTER (WHERE has_pricing_match AND price_min IS NULL)
        AS matched_without_valid_price_item_count,
    COUNT(*) FILTER (WHERE price_min IS NOT NULL) AS valid_price_item_count,
    COUNT(*) FILTER (WHERE COALESCE(has_buy, FALSE)) AS buy_option_item_count,
    COUNT(*) FILTER (WHERE COALESCE(has_rent, FALSE)) AS rental_option_item_count,
    COUNT(*) FILTER (WHERE price_buy_min IS NOT NULL) AS buy_valid_price_item_count,
    COUNT(*) FILTER (WHERE rental_days_min IS NOT NULL) AS rental_term_available_item_count,
    COUNT(*) FILTER (WHERE is_required_inferred) AS inferred_required_item_count,
    COUNT(*) FILTER (WHERE NOT is_required_inferred) AS inferred_optional_item_count,
    COUNT(*) FILTER (WHERE is_oer) AS oer_item_count,
    COUNT(*) FILTER (WHERE is_oer IS NULL) AS oer_unclassified_item_count,
    COUNT(*) FILTER (WHERE is_ia) AS ia_item_count,
    COUNT(*) FILTER (WHERE is_ia IS NULL) AS ia_unclassified_item_count,
    COUNT(*) FILTER (WHERE has_enrollment) AS raw_enrollment_item_count,
    COUNT(*) FILTER (WHERE enrollment_assigned IS NOT NULL) AS assigned_enrollment_item_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE has_pricing_match) / NULLIF(COUNT(*), 0), 2)
        AS pct_pricing_match_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE NOT has_pricing_match) / NULLIF(COUNT(*), 0), 2)
        AS pct_unmatched_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE has_pricing_match AND price_min IS NULL)
        / NULLIF(COUNT(*), 0), 2) AS pct_matched_without_valid_price_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE price_min IS NOT NULL) / NULLIF(COUNT(*), 0), 2)
        AS pct_valid_price_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE COALESCE(has_buy, FALSE)) / NULLIF(COUNT(*), 0), 2)
        AS pct_buy_option_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE COALESCE(has_rent, FALSE)) / NULLIF(COUNT(*), 0), 2)
        AS pct_rental_option_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE price_buy_min IS NOT NULL) / NULLIF(COUNT(*), 0), 2)
        AS pct_buy_valid_price_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE rental_days_min IS NOT NULL) / NULLIF(COUNT(*), 0), 2)
        AS pct_rental_term_available_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_required_inferred) / NULLIF(COUNT(*), 0), 2)
        AS pct_inferred_required_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE NOT is_required_inferred) / NULLIF(COUNT(*), 0), 2)
        AS pct_inferred_optional_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_oer) / NULLIF(COUNT(*), 0), 2)
        AS pct_oer_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_ia) / NULLIF(COUNT(*), 0), 2)
        AS pct_ia_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE has_enrollment) / NULLIF(COUNT(*), 0), 2)
        AS pct_raw_enrollment_of_items,
    ROUND(100.0 * COUNT(*) FILTER (WHERE enrollment_assigned IS NOT NULL) / NULLIF(COUNT(*), 0), 2)
        AS pct_assigned_enrollment_of_items
FROM material_costs
WHERE 1 = 1
[[ AND {{period_sortable}} ]]
GROUP BY period_sortable
ORDER BY period_sortable
