#!/bin/bash
set -euo pipefail

# Export one release-dated CSV per material-bearing term from the canonical
# materialized Material Costs, Master Section, Master Institution, and Master ISBN
# models. Pass terms explicitly to limit the run, for example:
# scripts/export_cmm_masters.sh 2025-4

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$SCRIPT_DIR/dot.env" ]; then
    set -o allexport
    source "$SCRIPT_DIR/dot.env"
    set +o allexport
fi

DB="${MAIN_DB:-$REPO_ROOT/duckdb/commodore.duckdb}"
DUCKDB="${DUCKDB:-duckdb}"
OUT_DIR="${CMM_OUTPUT_DIR:-$REPO_ROOT/output/cmm}"
EXPORT_DATE="${CMM_EXPORT_DATE:-$(date +%Y%m%d)}"

if [[ ! "$EXPORT_DATE" =~ ^[0-9]{8}$ ]]; then
    echo "Error: CMM_EXPORT_DATE must be YYYYMMDD, got: $EXPORT_DATE" >&2
    exit 1
fi

if [ "$#" -gt 0 ]; then
    TERMS=("$@")
else
    terms_output=$(
        $DUCKDB -bail -readonly -list -noheader "$DB" -c "
            SELECT DISTINCT period_sortable
            FROM master_material
            WHERE period_sortable IS NOT NULL
              AND period_sortable >= '2024-1'
            ORDER BY period_sortable;
        "
    )
    TERMS=()
    if [ -n "$terms_output" ]; then
        mapfile -t TERMS <<< "$terms_output"
    fi
fi

if [ "${#TERMS[@]}" -eq 0 ]; then
    echo "Error: no material-bearing terms from 2024 onward were found" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

for term in "${TERMS[@]}"; do
    if [[ ! "$term" =~ ^[0-9]{4}-[1-4]$ ]]; then
        echo "Error: term must use YYYY-N with N in 1..4, got: $term" >&2
        exit 1
    fi

    term_slug=${term/-/_}
    section_file="$OUT_DIR/master_section_${term_slug}_${EXPORT_DATE}.csv"
    institution_file="$OUT_DIR/master_institution_${term_slug}_${EXPORT_DATE}.csv"
    isbn_file="$OUT_DIR/master_isbn_${term_slug}_${EXPORT_DATE}.csv"
    master_material_file="$OUT_DIR/master_material_${term_slug}_${EXPORT_DATE}.csv"
    # COPY paths are SQL string literals. Double embedded apostrophes so a valid
    # output directory such as /tmp/team's-release remains data, not SQL syntax.
    section_file_sql=${section_file//\'/\'\'}
    institution_file_sql=${institution_file//\'/\'\'}
    isbn_file_sql=${isbn_file//\'/\'\'}
    master_material_file_sql=${master_material_file//\'/\'\'}

    model_counts=$(
        $DUCKDB -bail -readonly -list -noheader -separator ' ' "$DB" -c "
            SELECT
                (SELECT COUNT(*) FROM master_section WHERE period_sortable = '${term}'),
                (SELECT COUNT(*) FROM master_institution WHERE period_sortable = '${term}'),
                (SELECT COUNT(*) FROM master_isbn WHERE period_sortable = '${term}'),
                (SELECT COUNT(*) FROM master_material WHERE period_sortable = '${term}');
        "
    )
    read -r section_rows institution_rows isbn_rows master_material_rows <<< "$model_counts"
    if [ "$section_rows" -eq 0 ] || [ "$institution_rows" -eq 0 ] || [ "$isbn_rows" -eq 0 ] \
        || [ "$master_material_rows" -eq 0 ]; then
        echo "Error: canonical models have no complete output for ${term}; rebuild them after importing that term" >&2
        exit 1
    fi

    echo "[EXPORT] Master Section ${term} -> ${section_file#$REPO_ROOT/} (${section_rows} rows)"
    echo "[EXPORT] Master Institution ${term} -> ${institution_file#$REPO_ROOT/} (${institution_rows} rows)"
    echo "[EXPORT] Master ISBN ${term} -> ${isbn_file#$REPO_ROOT/} (${isbn_rows} rows)"
    echo "[EXPORT] Master Material ${term} -> ${master_material_file#$REPO_ROOT/} (${master_material_rows} rows)"
    $DUCKDB -bail -readonly "$DB" <<SQL
SET memory_limit='8GB';
SET threads=4;

COPY (
    SELECT * FROM master_section
    WHERE period_sortable = '${term}'
    ORDER BY section_id
) TO '${section_file_sql}' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM master_institution
    WHERE period_sortable = '${term}'
    ORDER BY unit_id
) TO '${institution_file_sql}' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM master_isbn
    WHERE period_sortable = '${term}'
    ORDER BY isbn13
) TO '${isbn_file_sql}' (HEADER, DELIMITER ',');

COPY (
    SELECT * FROM master_material
    WHERE period_sortable = '${term}'
    ORDER BY section_id, isbn13
) TO '${master_material_file_sql}' (HEADER, DELIMITER ',');

SELECT
    '${term}' AS period_sortable,
    ${section_rows} AS section_rows,
    ${institution_rows} AS institution_rows,
    ${isbn_rows} AS isbn_rows,
    ${master_material_rows} AS master_material_rows;
SQL
done

echo "Exported ${#TERMS[@]} term(s) to ${OUT_DIR}"
