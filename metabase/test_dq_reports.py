#!/usr/bin/env python3
"""Regression contracts for Metabase DQ report classification and labeling."""

from __future__ import annotations

import csv
import io
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
QUESTIONS = ROOT / "metabase/questions"
PRODUCTION_DATABASE = ROOT / "duckdb/commodore.duckdb"
DUCKDB = shutil.which("duckdb")

FIXTURE = """
CREATE TABLE __data_quality_metrics (
    category VARCHAR,
    check_id VARCHAR,
    metric_name VARCHAR,
    metric_value BIGINT
);
INSERT INTO __data_quality_metrics VALUES
    ('pricing', 'residual_grain', 'unexplained_residual', 0),
    ('pricing', 'tall_vs_wide_parity', 'difference', 0),
    ('wide', 'price_avg_sanity', 'rows_below_min', 7),
    ('wide', 'price_avg_sanity', 'rows_above_max', 0),
    ('wide', 'price_avg_sanity', 'rows_with_null_bounds', 7),
    ('catalog', 'classification_consistency', 'oer_inconsistent_pairs', 0),
    ('catalog', 'classification_consistency', 'ia_inconsistent_pairs', 0),
    ('pricing', 'price_outliers', 'price_null', 0),
    ('pricing', 'price_outliers', 'price_zero', 3),
    ('pricing', 'price_outliers', 'price_under_1', 4),
    ('pricing', 'price_outliers', 'price_over_1000', 5);
"""


def render_question(name: str) -> str:
    lines = []
    for line in (QUESTIONS / name).read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("-- ") and ":" in stripped[3:]:
            continue
        lines.append(line)
    return re.sub(r"\[\[.*?\]\]", "", "\n".join(lines), flags=re.DOTALL).strip()


def query(database: Path, sql: str, *, read_only: bool = False) -> list[dict[str, str]]:
    command = [DUCKDB, "-bail", "-csv"]
    if read_only:
        command.append("-readonly")
    command.append(str(database))
    result = subprocess.run(
        command,
        input=sql,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise AssertionError(result.stderr.strip())
    return list(csv.DictReader(io.StringIO(result.stdout)))


def metric_names(rows: list[dict[str, str]]) -> set[str]:
    return {row["metric_name"] for row in rows}


@unittest.skipIf(DUCKDB is None, "DuckDB CLI is required")
class DqReportFixtureTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.database = Path(self.temporary_directory.name) / "dq-reports.duckdb"
        query(self.database, FIXTURE)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_null_bounds_are_availability_not_zero_invariant(self) -> None:
        critical = query(
            self.database,
            render_question("18_dq_critical_should_be_zero.sql"),
        )
        availability = query(
            self.database,
            render_question("07_dq_pricing_price_outliers.sql"),
        )

        self.assertNotIn("rows_with_null_bounds", metric_names(critical))
        self.assertEqual(
            next(row for row in critical if row["metric_name"] == "rows_below_min")[
                "metric_value"
            ],
            "7",
        )
        self.assertEqual(
            next(
                row
                for row in availability
                if row["metric_name"] == "rows_with_null_bounds"
            )["metric_value"],
            "7",
        )


@unittest.skipIf(DUCKDB is None, "DuckDB CLI is required")
@unittest.skipUnless(PRODUCTION_DATABASE.is_file(), "production DuckDB is unavailable")
class DqReportProductionReadOnlyTest(unittest.TestCase):
    def test_reports_match_persisted_dq_metric_classification(self) -> None:
        critical = query(
            PRODUCTION_DATABASE,
            render_question("18_dq_critical_should_be_zero.sql"),
            read_only=True,
        )
        availability = query(
            PRODUCTION_DATABASE,
            render_question("07_dq_pricing_price_outliers.sql"),
            read_only=True,
        )
        persisted = query(
            PRODUCTION_DATABASE,
            """
            SELECT check_id, metric_name, metric_value
            FROM __data_quality_metrics
            WHERE check_id IN ('price_avg_sanity', 'price_outliers')
            ORDER BY check_id, metric_name
            """,
            read_only=True,
        )

        persisted_by_name = {row["metric_name"]: row["metric_value"] for row in persisted}
        critical_by_name = {row["metric_name"]: row["metric_value"] for row in critical}
        availability_by_name = {
            row["metric_name"]: row["metric_value"] for row in availability
        }
        self.assertNotIn("rows_with_null_bounds", critical_by_name)
        self.assertEqual(
            critical_by_name["rows_below_min"], persisted_by_name["rows_below_min"]
        )
        self.assertEqual(
            critical_by_name["rows_above_max"], persisted_by_name["rows_above_max"]
        )
        self.assertEqual(
            availability_by_name["rows_with_null_bounds"],
            persisted_by_name["rows_with_null_bounds"],
        )


if __name__ == "__main__":
    unittest.main()
