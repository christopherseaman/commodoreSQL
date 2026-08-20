-- name: Master Institution by Term
-- description: One row per period_sortable × unit_id from 2024 onward (#54). Includes IPEDS attributes, deterministic bookstore URL, section/course and course-level counts, material/required/inferred-required/optional/supply/OER/IA/pricing/ISBN coverage, and assigned-enrollment/valid-seat coverage and totals. NULL unit_id is retained as one unknown-institution bucket per term so section totals reconcile. Priced counts use the status-aligned names, correcting the reversed Req/Opt prose in the source workbook.
SELECT * FROM master_institution
