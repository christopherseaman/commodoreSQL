#!/usr/bin/env python3
"""Verify every supported DuckDB CLI path stops at its first SQL error."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parent.parent
DUCKDB = shutil.which("duckdb")
ERROR_THEN_VALID_SQL = """
SELECT * FROM issue_82_missing_relation;
SELECT 'issue_82_bail_sentinel' AS later_statement;
"""

RUNNER_CONTRACTS = {
    "scripts/run_sql.sh": ("${DUCKDB}", "${DUCKDB} -bail", 7),
    "scripts/export_all.sh": ("$DUCKDB", "$DUCKDB -bail", 1),
    "scripts/export_all_parquet.sh": ("${DUCKDB}", "${DUCKDB} -bail", 1),
    "scripts/export_course_material.sh": (
        '"${DUCKDB_ARGS[@]}"',
        '"${DUCKDB_ARGS[@]}" -bail',
        1,
    ),
    "scripts/export_cmm_masters.sh": ("$DUCKDB", "$DUCKDB -bail", 3),
    "scripts/export_fall2025_subsets.sh": ("$DUCKDB", "$DUCKDB -bail", 2),
    "scripts/classify_supplies.sh": ("$DUCKDB", "$DUCKDB -bail", 2),
}


class DuckDBBailTest(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        self.assertIsNotNone(DUCKDB, "duckdb CLI is required by the checked-in runners")
        return subprocess.run(
            [DUCKDB, *args],
            input=ERROR_THEN_VALID_SQL,
            text=True,
            capture_output=True,
            check=False,
        )

    def assert_bails(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("issue_82_bail_sentinel", result.stdout + result.stderr)

    def test_stdin_sql_stops_before_later_statement(self) -> None:
        self.assert_bails(self.run_cli("-bail", ":memory:"))

    def test_command_sql_stops_before_later_statement(self) -> None:
        self.assert_bails(self.run_cli("-bail", ":memory:", "-c", ERROR_THEN_VALID_SQL))

    def test_readonly_argument_order_stops_before_later_statement(self) -> None:
        with tempfile.TemporaryDirectory(prefix="duckdb-bail-") as temp_directory:
            database = Path(temp_directory) / "smoke.duckdb"
            subprocess.run(
                [DUCKDB, "-bail", str(database), "-c", "CREATE TABLE smoke(value INTEGER);"],
                text=True,
                capture_output=True,
                check=True,
            )
            self.assert_bails(self.run_cli("-bail", "-readonly", str(database)))
            self.assert_bails(
                self.run_cli(
                    "-bail",
                    "-readonly",
                    "-list",
                    "-noheader",
                    str(database),
                    "-c",
                    ERROR_THEN_VALID_SQL,
                )
            )

    def test_supported_runners_force_bail(self) -> None:
        for relative_path, (command, invocation, expected_count) in RUNNER_CONTRACTS.items():
            with self.subTest(runner=relative_path):
                source = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
                self.assertEqual(source.count(command), expected_count)
                self.assertEqual(source.count(invocation), expected_count)

    def test_csv_runner_propagates_first_failure(self) -> None:
        source = (REPO_ROOT / "scripts/export_all.sh").read_text(encoding="utf-8")
        self.assertIn("set -euo pipefail", source)
        self.assertNotIn("((current_export++))", source)

    def test_parquet_runner_stops_after_failed_export(self) -> None:
        source = (REPO_ROOT / "scripts/export_all_parquet.sh").read_text(encoding="utf-8")
        failure_branch = source.split('echo "✗ Failed to export ${export_name}"', 1)[1]
        self.assertIn("exit 1", failure_branch.split("fi", 1)[0])


if __name__ == "__main__":
    unittest.main()
