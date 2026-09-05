#!/usr/bin/env python3
"""Static and isolated contracts for the mailing recency boundary."""

from pathlib import Path
import re
import shutil
import subprocess
import sys


REPO_ROOT = Path(__file__).resolve().parent.parent
MAILING_SQL = REPO_ROOT / "scripts/sql/3_mailing_lists.sql"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def view_definition(sql: str, name: str) -> str:
    match = re.search(rf"CREATE VIEW {name} AS\n(.*?);", sql, re.DOTALL)
    if match is None:
        fail(f"missing CREATE VIEW {name} definition")
    return match.group(1)


def assert_static_contract(recent_periods_sql: str, current_mailing_sql: str) -> None:
    if "FROM ${SURVEY_TABLE}" not in recent_periods_sql:
        fail("recent_periods must derive directly from ${SURVEY_TABLE}")
    if "master_mailing" in recent_periods_sql or "comprehensive_data" in recent_periods_sql:
        fail("recent_periods must not derive from a selected or enriched relation")
    for clause in ("WHERE period_sortable IS NOT NULL", "ORDER BY period_sortable DESC", "LIMIT 12"):
        if clause not in recent_periods_sql:
            fail(f"recent_periods is missing {clause}")

    required_current_fragments = (
        "FROM master_mailing m",
        "LEFT JOIN panel_email p ON m.email = p.email",
        "m.period_sortable IN (SELECT period_sortable FROM recent_periods)",
        "NOT EXISTS (",
        "FROM opt_out o",
        "WHERE o.email = m.email",
    )
    for fragment in required_current_fragments:
        if fragment not in current_mailing_sql:
            fail(f"current_mailing is missing its working-population filter: {fragment}")


def assert_isolated_behavior(recent_periods_sql: str, current_mailing_sql: str) -> None:
    duckdb = shutil.which("duckdb")
    if duckdb is None:
        fail("DuckDB CLI is required for the isolated mailing contract test")

    catalog_terms = (
        "2026-1", "2025-4", "2025-3", "2025-2", "2025-1", "2024-4", "2024-3",
        "2024-2", "2024-1", "2023-4", "2023-3", "2023-2", "2023-1",
    )
    catalog_values = ", ".join(f"('{term}')" for term in catalog_terms)
    setup = f"""
CREATE TABLE course_catalog_test (period_sortable VARCHAR);
INSERT INTO course_catalog_test VALUES {catalog_values};
CREATE TABLE master_mailing (email VARCHAR, period_sortable VARCHAR);
INSERT INTO master_mailing VALUES
    ('recent@example.edu', '2025-4'),
    ('opted@example.edu', '2025-3'),
    ('old@example.edu', '2023-1');
CREATE TABLE panel_email (email VARCHAR, panel_response_year VARCHAR);
INSERT INTO panel_email VALUES ('recent@example.edu', 'OER_2025');
CREATE TABLE opt_out (email VARCHAR);
INSERT INTO opt_out VALUES ('opted@example.edu');
CREATE VIEW recent_periods AS
{recent_periods_sql.replace('${SURVEY_TABLE}', 'course_catalog_test')};
CREATE VIEW current_mailing AS
{current_mailing_sql};
SELECT COUNT(*), MIN(period_sortable), MAX(period_sortable)
FROM recent_periods;
SELECT COUNT(*), MIN(email), MAX(panel_response_year)
FROM current_mailing;
"""
    result = subprocess.run(
        [duckdb, "-bail", "-csv", "-noheader", ":memory:"],
        input=setup,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        fail(f"isolated DuckDB contract failed: {result.stderr.strip()}")
    output = result.stdout.strip().splitlines()
    if output != ["12,2023-2,2026-1", "1,recent@example.edu,OER_2025"]:
        fail(f"unexpected isolated mailing result: {output}")


def main() -> None:
    sql = MAILING_SQL.read_text()
    recent_periods_sql = view_definition(sql, "recent_periods")
    current_mailing_sql = view_definition(sql, "current_mailing")
    assert_static_contract(recent_periods_sql, current_mailing_sql)
    assert_isolated_behavior(recent_periods_sql, current_mailing_sql)
    print("PASS: catalog recency boundary and Mailing Working filters are preserved.")


if __name__ == "__main__":
    main()
