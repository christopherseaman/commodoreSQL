#!/bin/bash
set -euo pipefail

# Export the canonical course-material relations on demand. The full pipeline
# deliberately does not invoke this script because the exports can be large.
# Usage:
#   scripts/export_course_material.sh                 # all terms, today's date
#   scripts/export_course_material.sh 20250828        # all terms, release date
#   scripts/export_course_material.sh 2025-4           # one term, today's date
#   scripts/export_course_material.sh 20250828 2025-4 # one term, release date

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Explicit process-environment values take precedence over the ignored local
# configuration, matching the pipeline runner's override contract.
CM_MAIN_DB_OVERRIDE="${MAIN_DB-}"
CM_DUCKDB_OVERRIDE="${DUCKDB-}"
if [ -f "$SCRIPT_DIR/dot.env" ]; then
    set -o allexport
    source "$SCRIPT_DIR/dot.env"
    set +o allexport
fi
if [ -n "$CM_MAIN_DB_OVERRIDE" ]; then
    MAIN_DB="$CM_MAIN_DB_OVERRIDE"
fi
if [ -n "$CM_DUCKDB_OVERRIDE" ]; then
    DUCKDB="$CM_DUCKDB_OVERRIDE"
fi
unset CM_MAIN_DB_OVERRIDE CM_DUCKDB_OVERRIDE

DB="${MAIN_DB:-$REPO_ROOT/duckdb/commodore.duckdb}"
DUCKDB="${DUCKDB:-duckdb}"
OUT_DIR="${COURSE_MATERIALS_OUTPUT_DIR:-${CMM_OUTPUT_DIR:-$REPO_ROOT/output/course_material}}"
EXPORT_DATE="${CMM_EXPORT_DATE:-$(date +%Y%m%d)}"
TERM=""
# dot.env may include trusted DuckDB flags.
# Split that configured command into argv before appending this script's flags;
# invoking the whole string as one executable would fail with command-not-found.
read -r -a DUCKDB_ARGS <<< "$DUCKDB"
if [ "${#DUCKDB_ARGS[@]}" -eq 0 ]; then
    echo "Error: DUCKDB command is empty" >&2
    exit 1
fi

if [ "$#" -gt 2 ]; then
    echo "Usage: $0 [YYYYMMDD] [YYYY-N]" >&2
    exit 2
fi

if [ "$#" -ge 1 ]; then
    if [[ "$1" =~ ^[0-9]{8}$ ]]; then
        EXPORT_DATE="$1"
    elif [[ "$1" =~ ^[0-9]{4}-[1-4]$ ]]; then
        TERM="$1"
    else
        echo "Error: first argument must be export date YYYYMMDD or term YYYY-N, got: $1" >&2
        exit 2
    fi
fi
if [ "$#" -eq 2 ]; then
    if [[ "$1" != [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9] ]] || [[ ! "$2" =~ ^[0-9]{4}-[1-4]$ ]]; then
        echo "Usage: $0 [YYYYMMDD] [YYYY-N]" >&2
        exit 2
    fi
    EXPORT_DATE="$1"
    TERM="$2"
fi

if [[ ! "$EXPORT_DATE" =~ ^[0-9]{8}$ ]]; then
    echo "Error: CMM_EXPORT_DATE must be YYYYMMDD, got: $EXPORT_DATE" >&2
    exit 1
fi
if [ ! -f "$DB" ]; then
    echo "Error: DuckDB database not found: $DB" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

term_slug=""
term_predicate=""
if [ -n "$TERM" ]; then
    term_slug="_${TERM/-/_}"
    term_predicate=" AND period_sortable = '${TERM}'"
fi

copy_path_sql() {
    local path="$1"
    printf "%s" "${path//\'/\'\'}"
}

# The relation names are fixed, validated canonical contracts; paths are
# escaped as SQL literals before being interpolated into the read-only COPY.
declare -a EXPORTS=(
    "course_material|course_material${term_slug}_${EXPORT_DATE}.csv|period_sortable, section_id, isbn13|TRUE"
    "course_material_recent|course_material_recent${term_slug}_${EXPORT_DATE}.csv|period_sortable, section_id, isbn13|TRUE"
    "course_material_use|course_material_use_recent${term_slug}_${EXPORT_DATE}.csv|period_sortable, section_id, isbn13|TRUE"
    "course_material_no_use|course_material_no_use_recent${term_slug}_${EXPORT_DATE}.csv|period_sortable, section_id, isbn13|TRUE"
    "course_material_no_use|course_material_can_recent${term_slug}_${EXPORT_DATE}.csv|period_sortable, section_id, isbn13|is_canada"
)

# Refuse to replace an existing dated release. Build every file in one staging
# directory so a failed relation does not leave a partial release in OUT_DIR.
declare -a OUTPUT_FILENAMES=()
for export_spec in "${EXPORTS[@]}"; do
    IFS='|' read -r _ filename _ _ <<< "$export_spec"
    if [ -e "$OUT_DIR/$filename" ]; then
        echo "Error: refusing to overwrite existing export: $OUT_DIR/$filename" >&2
        exit 1
    fi
    OUTPUT_FILENAMES+=("$filename")
done

STAGING_DIR="$(mktemp -d "$OUT_DIR/.course_material_export.XXXXXX")"
cleanup_staging() {
    rm -r -- "$STAGING_DIR"
}
trap cleanup_staging EXIT

for export_spec in "${EXPORTS[@]}"; do
    IFS='|' read -r relation filename ordering predicate <<< "$export_spec"
    output_path="$OUT_DIR/$filename"
    staged_path="$STAGING_DIR/$filename"
    output_path_sql=$(copy_path_sql "$staged_path")
    echo "[EXPORT] ${relation}${TERM:+ (${TERM})} -> ${output_path#$REPO_ROOT/}"
    "${DUCKDB_ARGS[@]}" -bail -readonly "$DB" <<SQL
COPY (
    SELECT * FROM ${relation} WHERE ${predicate}${term_predicate}
    ORDER BY ${ordering}
) TO '${output_path_sql}' (HEADER, DELIMITER ',');
SQL
done

for filename in "${OUTPUT_FILENAMES[@]}"; do
    mv --no-clobber -- "$STAGING_DIR/$filename" "$OUT_DIR/$filename"
    if [ -e "$STAGING_DIR/$filename" ]; then
        echo "Error: export appeared concurrently; refusing to overwrite: $OUT_DIR/$filename" >&2
        exit 1
    fi
done
rmdir -- "$STAGING_DIR"
trap - EXIT

echo "Exported ${#EXPORTS[@]} course-material file(s) to $OUT_DIR${TERM:+ for $TERM}"
