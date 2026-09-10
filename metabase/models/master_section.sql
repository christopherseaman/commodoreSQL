-- name: Master Section
-- description: Material-bearing sections; inherited enrollment/audits, required/all-material price bounds, and modal URL. All values derive from master_material. Excluded-item section audits pass through unchanged, not summed across material copies. Full-population diagnostics remain upstream. Price averages are bound midpoints at section grain; seats_taken=9999 is invalid.
SELECT * FROM master_section
