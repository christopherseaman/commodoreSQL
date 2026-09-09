#!/usr/bin/env python3
"""Numerical contracts for Metabase price-summary consumers."""

from __future__ import annotations

import csv
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
QUESTIONS = ROOT / "metabase/questions"
DUCKDB = shutil.which("duckdb")

FIXTURE = r"""
CREATE TABLE master_section (
    section_id VARCHAR, course_id VARCHAR, course_subject VARCHAR,
    course_level VARCHAR, state VARCHAR, period_sortable VARCHAR,
    sector VARCHAR, control VARCHAR, level VARCHAR,
    required_count BIGINT, required_priced_count BIGINT,
    optional_priced_count BIGINT, required_price_min DOUBLE,
    required_price_avg DOUBLE, required_price_max DOUBLE,
    required_price_buy_min DOUBLE, required_price_buy_max DOUBLE,
    all_price_min DOUBLE, all_price_avg DOUBLE, all_price_max DOUBLE,
    enrollment_assigned BIGINT, enrollment_source VARCHAR
);
INSERT INTO master_section VALUES
    ('s1', 'c1', 'Biology', 'Introductory or general undergraduate', 'CA',
     '2025-4', 'Public, 2-year', 'Public',
     'At least 2 but less than 4 years', 1, 1, 1,
     10, 15, 20, 12, 18, 10, 25, 40, 10, 'own'),
    ('s2', 'c2', 'Biology', 'Introductory or general undergraduate', 'CA',
     '2025-4', 'Public, 2-year', 'Public',
     'At least 2 but less than 4 years', 2, 2, 1,
     100, 150, 200, 120, 180, 120, 180, 240, 30, 'assigned');
CREATE TABLE state_region (state VARCHAR, region VARCHAR);
"""


def render_question(name: str) -> str:
    """Remove frontmatter and omit unset Metabase optional filter blocks."""
    lines = []
    for line in (QUESTIONS / name).read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("-- ") and ":" in stripped[3:]:
            continue
        lines.append(line)
    return re.sub(r"\[\[.*?\]\]", "", "\n".join(lines), flags=re.DOTALL).strip()


def query(database: Path, sql: str) -> list[dict[str, str]]:
    result = subprocess.run(
        [DUCKDB, "-bail", "-csv", str(database)],
        input=sql,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise AssertionError(result.stderr.strip())
    return list(csv.DictReader(io.StringIO(result.stdout)))


@unittest.skipIf(DUCKDB is None, "DuckDB CLI is required")
class PriceSummaryReportTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.database = Path(self.temporary_directory.name) / "reports.duckdb"
        query(self.database, FIXTURE)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def run_report(self, name: str) -> dict[str, str]:
        rows = query(self.database, render_question(name))
        self.assertEqual(len(rows), 1)
        return rows[0]

    def test_general_reports_recompute_midrange_at_output_grain(self) -> None:
        subject = self.run_report("24_cost_required_by_subject.sql")
        level = self.run_report("25_cost_owned_vs_all.sql")
        report = self.run_report("40_report_cost.sql")

        # Group bounds produce 105, unlike AVG(section midpoint) = 82.5.
        self.assertEqual(float(subject["required_price_midrange"]), 105.0)
        self.assertEqual(float(subject["required_buy_price_midrange"]), 96.0)
        self.assertEqual(float(subject["required_price_min"]), 10.0)
        self.assertEqual(float(subject["required_price_max"]), 200.0)
        self.assertNotEqual(float(subject["required_price_midrange"]), 82.5)
        self.assertEqual(float(level["all_options_price_midrange"]), 105.0)
        self.assertEqual(float(level["buy_price_midrange"]), 96.0)
        self.assertEqual(float(report["required_price_midrange"]), 105.0)
        self.assertEqual(float(report["required_buy_price_midrange"]), 96.0)
        self.assertEqual(float(report["all_material_price_midrange"]), 125.0)

    def test_commissioned_analyses_preserve_section_estimators(self) -> None:
        tally = self.run_report("42_fall2025_tally_cost_by_class.sql")
        hypothesis = self.run_report("47_fall2025_hypothesis_enrollwt_cost.sql")

        self.assertEqual(float(tally["section_median_required_price"]), 82.5)
        self.assertEqual(float(tally["section_median_required_buy_price"]), 82.5)
        self.assertEqual(float(tally["section_median_all_material_price"]), 102.5)
        self.assertEqual(float(hypothesis["section_median_required_price"]), 82.5)
        self.assertEqual(
            float(hypothesis["enrollment_weighted_mean_required_price"]),
            116.25,
        )
        self.assertEqual(
            float(hypothesis["own_enrollment_weighted_mean_required_price"]),
            15.0,
        )

    def test_bar_visualization_uses_current_query_aliases(self) -> None:
        settings = json.loads(
            (QUESTIONS / "25_cost_owned_vs_all.viz.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            settings["graph.metrics"],
            ["all_options_price_midrange", "buy_price_midrange"],
        )
        sql = render_question("25_cost_owned_vs_all.sql")
        for metric in settings["graph.metrics"]:
            self.assertRegex(sql, rf"\bAS\s+{metric}\b")


if __name__ == "__main__":
    unittest.main()
