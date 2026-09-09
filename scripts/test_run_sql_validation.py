#!/usr/bin/env python3
"""Integration checks for selected-stage output validation in run_sql.sh."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parent.parent
RUNNER = REPO_ROOT / "scripts/run_sql.sh"
DUCKDB = shutil.which("duckdb")
ENVSUBST = shutil.which("envsubst")


@unittest.skipUnless(DUCKDB and ENVSUBST, "duckdb and envsubst are required")
class RunSqlValidationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="run-sql-validation-")
        self.root = Path(self.temp.name)
        scripts = self.root / "scripts"
        (scripts / "sql" / "exports").mkdir(parents=True)
        (scripts / "tmp").mkdir()
        shutil.copy2(RUNNER, scripts / "run_sql.sh")
        (scripts / "export_all.sh").write_text("#!/bin/bash\nexit 0\n")
        (scripts / "sql" / "config.sql").write_text("SELECT 1;\n")
        database = self.root / "fixture.duckdb"
        (scripts / "dot.env").write_text(
            f"MAIN_DB='{database}'\nPRICING_CSV='{self.root / 'unused.csv'}'\n"
            "MEM_LIMIT='1GB'\nNUM_THREADS='1'\n"
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_sql(self, relative_path: str, sql: str) -> None:
        path = self.root / "scripts" / "sql" / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(sql)

    def run_selected(self, *sql_files: str) -> subprocess.CompletedProcess[str]:
        command = 'CUSTOM_SQL_FILES=("$@"); source ./run_sql.sh'
        return subprocess.run(
            ["bash", "-c", command, "runner", *sql_files],
            cwd=self.root / "scripts",
            env={**os.environ, "DUCKDB": DUCKDB},
            text=True,
            capture_output=True,
            check=False,
        )

    def assert_success(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_full_release_tables_and_views_pass(self) -> None:
        self.write_sql(
            "2_oer_classification.sql",
            "CREATE TABLE comprehensive_data(value INTEGER);",
        )
        self.write_sql(
            "2b_course_material.sql",
            """
            CREATE TABLE course_material(value INTEGER);
            CREATE VIEW course_material_recent AS SELECT * FROM course_material;
            CREATE VIEW course_material_use AS SELECT * FROM course_material;
            CREATE VIEW course_material_no_use AS SELECT * FROM course_material;
            """,
        )
        self.write_sql("2c_pricing_wide.sql", "CREATE TABLE pricing_wide(value INTEGER);")
        self.write_sql(
            "3_mailing_lists.sql",
            "CREATE TABLE master_mailing(value INTEGER); "
            "CREATE VIEW current_mailing AS SELECT * FROM master_mailing;",
        )
        self.write_sql("3b_master_material.sql", "CREATE TABLE master_material(value INTEGER);")
        self.write_sql(
            "4_merged_records.sql",
            """
            CREATE TABLE master_section(value INTEGER);
            CREATE VIEW master_course AS SELECT * FROM master_section;
            CREATE VIEW sample_section_us_intro_fall2025 AS SELECT * FROM master_section;
            """,
        )

        result = self.run_selected(
            "2_oer_classification.sql",
            "2b_course_material.sql",
            "2c_pricing_wide.sql",
            "3_mailing_lists.sql",
            "3b_master_material.sql",
            "4_merged_records.sql",
        )

        self.assert_success(result)

    def test_missing_selected_output_fails(self) -> None:
        self.write_sql("3b_master_material.sql", "SELECT 1;")
        result = self.run_selected("3b_master_material.sql")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("master_material: expected BASE TABLE, found MISSING", result.stderr)

    def test_wrong_relation_type_fails(self) -> None:
        self.write_sql("2_oer_classification.sql", "CREATE VIEW comprehensive_data AS SELECT 1;")
        result = self.run_selected("2_oer_classification.sql")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("comprehensive_data: expected BASE TABLE, found VIEW", result.stderr)

    def test_intentional_partial_run_validates_only_its_output(self) -> None:
        self.write_sql("3b_master_material.sql", "CREATE TABLE master_material(value INTEGER);")
        self.assert_success(self.run_selected("3b_master_material.sql"))

    def test_unselected_export_remains_export_only(self) -> None:
        self.write_sql("exports/fixture_export.sql", "SELECT 1 AS value")
        result = self.run_selected("exports/fixture_export.sql")
        self.assert_success(result)
        self.assertTrue((self.root / "output" / "fixture_export.csv").is_file())


if __name__ == "__main__":
    unittest.main()
