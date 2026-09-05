#!/usr/bin/env python3
"""Verify panel raw staging is temporary and panel_email preserves its contract."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
DUCKDB = shutil.which("duckdb")


class PanelImportTest(unittest.TestCase):
    def test_raw_panel_is_connection_local_and_grouped_lookup_is_persistent(self):
        self.assertIsNotNone(DUCKDB, "duckdb CLI is required")
        setup = r"""
CREATE TEMP TABLE panel AS
SELECT * FROM (VALUES
    ('a@example.com', '2023'),
    ('a@example.com', '2024'),
    ('a@example.com', '2024'),
    ('b@example.com', NULL),
    ('c@example.com', '2022')) AS t(email, response_year);
CREATE TABLE panel_email AS
SELECT email,
       MAX(response_year) AS panel_response_year,
       COUNT(*) AS panel_source_row_count,
       COUNT(DISTINCT response_year) AS panel_response_year_variant_count
FROM panel
GROUP BY email;
SELECT CASE WHEN
    (SELECT COUNT(*) FROM panel_email) = 3 AND
    (SELECT panel_response_year FROM panel_email WHERE email='a@example.com') = '2024' AND
    (SELECT panel_source_row_count FROM panel_email WHERE email='a@example.com') = 3 AND
    (SELECT panel_response_year_variant_count FROM panel_email WHERE email='a@example.com') = 2 AND
    (SELECT panel_source_row_count FROM panel_email WHERE email='b@example.com') = 1 AND
    (SELECT panel_response_year_variant_count FROM panel_email WHERE email='b@example.com') = 0 AND
    (SELECT COUNT(*) FROM information_schema.tables
       WHERE table_name='panel' AND table_type='LOCAL TEMPORARY') = 1
THEN 1 ELSE error('panel lookup contract failed') END AS contract_ok;
"""
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "panel.duckdb"
            result = subprocess.run(
                [DUCKDB, "-bail", str(db), "-c", setup],
                text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("1", result.stdout)
            persisted = subprocess.run(
                [DUCKDB, "-bail", "-csv", "-noheader", str(db), "-c",
                 "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='panel';"],
                text=True, capture_output=True,
            )
            self.assertEqual(persisted.returncode, 0, persisted.stdout + persisted.stderr)
            self.assertEqual(persisted.stdout.strip(), "0")

    def test_setup_uses_temporary_raw_panel_table(self):
        source = (ROOT / "scripts/sql/0_setup.sql").read_text()
        self.assertIn("CREATE TEMP TABLE ${PANEL_TABLE} AS", source)
        self.assertIn("FROM ${PANEL_TABLE}", source)


if __name__ == "__main__":
    unittest.main()
