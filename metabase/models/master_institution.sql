-- name: Master Institution by Term (draft)
-- description: Draft institution/term rollup; material-bearing sections, including unknown institutions. Definition pending. All fields come from master_section, including modal nonblank bookstore URL (lexical tie-break). NULL unit_id remains one bucket per term, with NULL URL. Enrollment is assigned upstream; supply/exclusion audits cover only retained sections.
SELECT * FROM master_institution
