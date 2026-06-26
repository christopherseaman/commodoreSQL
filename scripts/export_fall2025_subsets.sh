#!/bin/bash
set -euo pipefail

# Re-runnable Parquet export of the Fall 2025 BMG analysis subsets (issue #35).
#
# Wraps the SAME SQL as the Metabase questions 37/38 in a COPY ... (FORMAT PARQUET).
# Question frontmatter lines are SQL comments, so the question files run verbatim —
# single source of truth, no filter duplicated here.
#
# Opens the DB read-only, so it coexists with Metabase's read lock (no `docker stop`).
# Outputs land in output/ (gitignored). Re-run after the supply-ISBN exclusion (#36)
# regenerates both files on the revised data with no changes here.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# MAIN_DB from dot.env if available, else the repo default
if [ -f "$SCRIPT_DIR/dot.env" ]; then
    set -o allexport; source "$SCRIPT_DIR/dot.env"; set +o allexport
fi
DB="${MAIN_DB:-$REPO_ROOT/duckdb/commodore.duckdb}"

OUT_DIR="$REPO_ROOT/output"
Q_DIR="$REPO_ROOT/metabase/questions"
# DUCKDB may carry flags (dot.env sets "duckdb -bail"); keep it unquoted for word-splitting.
DUCKDB="${DUCKDB:-duckdb}"
mkdir -p "$OUT_DIR"

export_one() {
    local question="$1" out_file="$2"
    echo "[EXPORT] ${question} -> output/${out_file}"
    $DUCKDB -readonly "$DB" <<SQL
SET memory_limit='8GB'; SET threads=4;
COPY (
$(cat "$Q_DIR/$question")
) TO '${OUT_DIR}/${out_file}' (FORMAT PARQUET);
SQL
}

export_one "37_fall2025_setA_has_required.sql" "fall2025_setA_required.parquet"
export_one "38_fall2025_setB_no_required.sql"  "fall2025_setB_no_required.parquet"

echo ""
echo "=== Export verification ==="
$DUCKDB -readonly "$DB" <<SQL
.mode box
SELECT 'setA_required'    AS file, COUNT(*) AS rows, COUNT(DISTINCT section_id) AS sections
FROM read_parquet('${OUT_DIR}/fall2025_setA_required.parquet')
UNION ALL
SELECT 'setB_no_required', COUNT(*),                 COUNT(DISTINCT section_id)
FROM read_parquet('${OUT_DIR}/fall2025_setB_no_required.parquet');
SQL
