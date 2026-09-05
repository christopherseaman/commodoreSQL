#!/usr/bin/env python3
"""Bounded integration fixture for the renamed canonical material flow."""

from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
SQL = ROOT / "scripts/sql"
DUCKDB = shutil.which("duckdb")


def render(path: Path) -> str:
    values = {
        "${CONFIG}": "",
        "${SURVEY_TABLE}": "course_catalog_20251215",
        "${IPEDS_TABLE}": "ipeds_data",
        "${PANEL_TABLE}": "panel",
        "${OPT_OUT_TABLE}": "opt_out",
        "${LOOKUP_DIR}": str(ROOT / "data/2025.12.15"),
    }
    text = path.read_text()
    for key, value in values.items():
        text = text.replace(key, value)
    return text


def cli(database: Path, sql: str) -> list[str]:
    result = subprocess.run(
        [DUCKDB, "-bail", "-csv", "-noheader", str(database)],
        input=sql,
        text=True,
        capture_output=True,
        cwd=ROOT / "scripts",
        check=False,
    )
    if result.returncode:
        raise AssertionError(result.stderr.strip())
    return [line for line in result.stdout.splitlines() if line]


class RenamedFlowPipelineTest(unittest.TestCase):
    """Exercises actual SQL stages only; fixture inputs are intentionally tiny."""

    @unittest.skipIf(DUCKDB is None, "DuckDB CLI is required")
    def test_renamed_flow_replays_with_canonical_population(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "fixture.duckdb"
            cli(database, self.fixture_sql())

            stages = (
                "0c_recent_period.sql",
                "1a_supply_classification.sql",
                "1b_section_enrollment.sql",
                "2_oer_classification.sql",
                "2b_course_material.sql",
                "2c_pricing_wide.sql",
                "3_mailing_lists.sql",
                "3b_master_material.sql",
                "4_merged_records.sql",
            )
            for stage in stages:
                cli(database, render(SQL / stage))
            self.materialize_models(database)

            self.assertEqual(
                cli(database, """
                    SELECT COUNT(*), COUNT(DISTINCT (period_sortable, section_id, isbn13)),
                           SUM(source_row_count)
                    FROM course_material WHERE isbn13 IS NOT NULL
                """),
                ["5,5,6"],
            )
            self.assertEqual(
                cli(database, """
                    SELECT section_id, isbn13, is_required_direct, is_required_inferred,
                           price_min, price_max, has_pricing_match
                    FROM master_material ORDER BY section_id, isbn13
                """),
                [
                    "1::BIO::101::002::2025-4,9780000000001,true,true,40.00,60.00,true",
                    "1::BIO::101::002::2025-4,9780000000002,false,false,20.00,20.00,true",
                ],
            )
            self.assertEqual(
                cli(database, """
                    SELECT material_count, required_count, optional_count,
                           required_cost_total_min, optional_cost_total_min
                    FROM master_section
                    WHERE section_id = '1::BIO::101::002::2025-4'
                """),
                ["2,1,1,40.00,20.00"],
            )
            self.assertEqual(
                cli(database, "SELECT COUNT(*) FROM course_material_no_use WHERE is_canada"),
                ["1"],
            )
            self.assertEqual(
                cli(database, "SELECT COUNT(*) FROM course_material_use WHERE is_supply OR no_materials"),
                ["0"],
            )
            self.assertEqual(
                cli(database, """
                    SELECT COUNT(*)
                    FROM information_schema.tables
                    WHERE table_schema = 'main'
                      AND table_name IN ('course_materials', 'course_materials_canada',
                                         'course_material_canada', 'material_costs')
                """),
                ["0"],
            )
            self.assertEqual(cli(database, "SELECT COUNT(*) FROM sample_material_10pct"), ["2"])
            self.assertEqual(cli(database, """
                WITH expected AS (
                    SELECT period_sortable, section_id, isbn13 FROM master_material
                    WHERE CAST('0x' || LEFT(md5(section_id), 16) AS UBIGINT) % 10 = 0
                ), actual AS (
                    SELECT period_sortable, section_id, isbn13 FROM sample_material_10pct
                )
                SELECT COUNT(*) FROM (
                    (SELECT * FROM expected EXCEPT SELECT * FROM actual)
                    UNION ALL
                    (SELECT * FROM actual EXCEPT SELECT * FROM expected)
                )
            """), ["0"])
            self.assertEqual(cli(database, "SELECT COUNT(*), COUNT(DISTINCT (period_sortable, unit_id)) FROM master_institution"), ["1,1"])
            self.assertEqual(cli(database, "SELECT COUNT(*), COUNT(DISTINCT (period_sortable, isbn13)) FROM master_isbn"), ["2,2"])
            self.assert_release_exports(database)

            # Replay the materialized stages against the same fixture database.
            cli(database, """
                CREATE TABLE course_materials (id INTEGER);
                CREATE TABLE material_costs (id INTEGER);
                CREATE TABLE sample10pct_materials (id INTEGER);
                CREATE VIEW course_materials_canada AS SELECT 1 AS id;
                CREATE VIEW course_material_canada AS SELECT 1 AS id;
                CREATE VIEW recent_periods AS SELECT '2025-4' AS period_sortable;
                CREATE VIEW course_material_post_2024 AS SELECT 1 AS id;
                CREATE VIEW master_section_us_intro_fall2025 AS SELECT 1 AS id;
            """)
            cli(database, render(SQL / "0_cleanup.sql"))
            self.assertEqual(cli(database, """
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = 'main'
                  AND table_name IN ('course_materials', 'material_costs', 'sample10pct_materials',
                                     'course_materials_canada', 'course_material_canada',
                                     'recent_periods', 'course_material_post_2024', 'master_section_us_intro_fall2025')
            """), ["0"])
            for stage in stages:
                cli(database, render(SQL / stage))
            self.materialize_models(database)
            self.assertEqual(cli(database, "SELECT COUNT(*), SUM(source_row_count) FROM course_material"), ["5,6"])
            self.assertEqual(cli(database, "SELECT COUNT(*) FROM master_material"), ["2"])
            self.assertEqual(cli(database, "SELECT COUNT(*) FROM master_institution"), ["1"])
            self.assertEqual(cli(database, "SELECT COUNT(*) FROM master_isbn"), ["2"])
            self.assert_release_exports(database)

    @staticmethod
    def materialize_models(database: Path) -> None:
        for name in ("master_institution", "master_isbn", "sample_material_10pct"):
            cli(database, f"CREATE OR REPLACE TABLE {name} AS\n" + render(SQL / "models" / f"{name}.sql"))

    def assert_release_exports(self, database: Path) -> None:
        sample_query = render(SQL / "exports/37_sample10_reconciliation.sql").strip().removesuffix(";")
        self.assertEqual(cli(database, f"""
            SELECT metric, full_value FROM ({sample_query})
            WHERE stage = 'comprehensive_data'
            ORDER BY metric
        """), ["enrollment_assigned_total,50", "section_rows,2"])

        coverage = (ROOT / "metabase/questions/68_coverage_section_enrollment_by_term.sql").read_text()
        optional_term = "[[ AND {{period_sortable}} ]]"
        self.assertIn(optional_term, coverage)
        coverage_rows = cli(database, coverage.replace(optional_term, ""))
        self.assertEqual(len(coverage_rows), 1)
        fields = coverage_rows[0].split(",")
        self.assertEqual(fields[:8], ["2025-4", "2", "2", "2", "50", "2", "50", "2"])
        self.assertEqual(fields[15], "1")  # Only one section is material-bearing.
        self.assertEqual(cli(database, coverage.replace(
            optional_term, "AND comprehensive_data.period_sortable = '2025-4'"
        )), coverage_rows)
        self.assertEqual(cli(database, coverage.replace(
            optional_term, "AND comprehensive_data.period_sortable = '2024-4'"
        )), [])

        release_rows = cli(database, render(SQL / "exports/38_cmm_release_reconciliation.sql"))
        self.assertGreater(len(release_rows), 0)
        self.assertTrue(all(row.endswith(",true") for row in release_rows), release_rows)

        key_rows = cli(database, render(SQL / "exports/39_cmm_release_key_reconciliation.sql"))
        self.assertEqual(key_rows, ["2025-4,1,1,0,0,true"])

        material_rows = cli(database, render(SQL / "exports/40_master_material_by_term.sql"))
        self.assertEqual(len(material_rows), 2)
        self.assertEqual(
            [row.split(",", 3)[:3] for row in material_rows],
            [["9780000000001", "Required Text", "A"], ["9780000000002", "Optional Text", "B"]],
        )

        material_qa_rows = cli(database, render(SQL / "exports/41_master_material_reconciliation.sql"))
        self.assertEqual(len(material_qa_rows), 2)
        self.assertTrue(all(row.endswith(",true") for row in material_qa_rows), material_qa_rows)

    @staticmethod
    def fixture_sql() -> str:
        return """
CREATE TABLE course_catalog_20251215 (
  ISBN13 BIGINT, Title VARCHAR, Author VARCHAR, Publisher VARCHAR, Imprint VARCHAR,
  Format VARCHAR, FormatType VARCHAR, book_status VARCHAR, unit_id BIGINT, school VARCHAR,
  state VARCHAR, dept_code VARCHAR, department VARCHAR, dept_description VARCHAR,
  course_number VARCHAR, section VARCHAR, course_title VARCHAR, course_level VARCHAR,
  course_subject VARCHAR, period VARCHAR, enrollments INTEGER, seats_taken INTEGER,
  instructor VARCHAR, first_name VARCHAR, last_name VARCHAR, email VARCHAR, course_id VARCHAR,
  section_id VARCHAR, period_sortable VARCHAR, period_date DATE
);
CREATE TABLE ipeds_data (unitid INTEGER, instnm VARCHAR, sector VARCHAR, iclevel VARCHAR,
  control VARCHAR, instsize VARCHAR, enroll_24 INTEGER, dist_enroll_24 INTEGER, inst_type VARCHAR);
CREATE TABLE opt_out (email VARCHAR, source VARCHAR);
CREATE TABLE panel (email VARCHAR, response_year VARCHAR);
CREATE TABLE panel_email (email VARCHAR, panel_response_year VARCHAR,
  panel_source_row_count BIGINT, panel_response_year_variant_count BIGINT);
CREATE TABLE pricing_historical (
  section_id VARCHAR, isbn13 BIGINT, unit_id BIGINT, required BOOLEAN, institute VARCHAR,
  bookstore_url VARCHAR, title VARCHAR, author VARCHAR, publisher VARCHAR, edition VARCHAR,
  book_option VARCHAR, book_condition VARCHAR, book_format VARCHAR, rental_days INTEGER,
  price DECIMAL(10,2), period_sortable VARCHAR
);
INSERT INTO ipeds_data VALUES (1, 'Fixture U', 'Public, 4-year or above', 'Four or more years',
  'Public', 'Under 5,000', 1000, 100, 'Public');
INSERT INTO panel_email VALUES ('teacher@example.edu', 'OER_2025', 1, 1);
INSERT INTO course_catalog_20251215 VALUES
  (9780000000001, 'Required Text', 'A', 'P', NULL, 'Print', 'Print', 'required', 1, 'Fixture U', 'CA', 'BIO', 'Biology', NULL, '101', '001', 'Biology', 'Introductory or general undergraduate', 'Biology', 'Fall 2025', 30, 25, 'Teacher', 'T', 'One', 'teacher@example.edu', '1::BIO::101', '1::BIO::101::002::2025-4', '2025-4', DATE '2025-10-01'),
  (9780000000001, 'Required Text', 'A', 'P', NULL, 'Print', 'Print', 'required', 1, 'Fixture U', 'CA', 'BIO', 'Biology', NULL, '101', '001', 'Biology', 'Introductory or general undergraduate', 'Biology', 'Fall 2025', 30, 25, 'Teacher', 'T', 'One', 'teacher@example.edu', '1::BIO::101', '1::BIO::101::002::2025-4', '2025-4', DATE '2025-10-01'),
  (9780000000002, 'Optional Text', 'B', 'P', NULL, 'Print', 'Print', 'recommended', 1, 'Fixture U', 'CA', 'BIO', 'Biology', NULL, '101', '001', 'Biology', 'Introductory or general undergraduate', 'Biology', 'Fall 2025', 30, 25, 'Teacher', 'T', 'One', 'teacher@example.edu', '1::BIO::101', '1::BIO::101::002::2025-4', '2025-4', DATE '2025-10-01'),
  (9780000000003, 'Lab Kit >supply<', 'C', 'P', NULL, 'Print', 'Print', 'required', 1, 'Fixture U', 'CA', 'BIO', 'Biology', NULL, '101', '001', 'Biology', 'Introductory or general undergraduate', 'Biology', 'Fall 2025', 30, 25, 'Teacher', 'T', 'One', 'teacher@example.edu', '1::BIO::101', '1::BIO::101::002::2025-4', '2025-4', DATE '2025-10-01'),
  (9780000000004, '*No Books Required*', NULL, NULL, NULL, 'Print', 'Print', NULL, 1, 'Fixture U', 'CA', 'BIO', 'Biology', NULL, '101', '001', 'Biology', 'Introductory or general undergraduate', 'Biology', 'Fall 2025', 30, 25, 'Teacher', 'T', 'One', 'teacher@example.edu', '1::BIO::101', '1::BIO::101::002::2025-4', '2025-4', DATE '2025-10-01'),
  (9780000000005, 'Canada Text', 'D', 'P', NULL, 'Print', 'Print', 'required', 1, 'Fixture U', 'CAN', 'BIO', 'Biology', NULL, '102', '001', 'Biology', 'Introductory or general undergraduate', 'Biology', 'Fall 2025', 20, 20, 'Teacher', 'T', 'One', 'teacher@example.edu', '1::BIO::102', '1::BIO::102::001::2025-4', '2025-4', DATE '2025-10-01');
INSERT INTO pricing_historical VALUES
  ('1::BIO::101::002::2025-4', 9780000000001, 1, true, 'Fixture U', 'https://books.example', 'Required Text', 'A', 'P', NULL, 'buy', 'new', 'physical', NULL, 40, '2025-4'),
  ('1::BIO::101::002::2025-4', 9780000000001, 1, true, 'Fixture U', 'https://books.example', 'Required Text', 'A', 'P', NULL, 'rental', 'new', 'physical', 120, 60, '2025-4'),
  ('1::BIO::101::002::2025-4', 9780000000002, 1, false, 'Fixture U', 'https://books.example', 'Optional Text', 'B', 'P', NULL, 'buy', 'new', 'physical', NULL, 20, '2025-4');
"""


if __name__ == "__main__":
    unittest.main()
