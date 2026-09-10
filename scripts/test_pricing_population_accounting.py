#!/usr/bin/env python3
"""Fixture test for the read-only #21 population accounting diagnostic."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
DUCKDB = shutil.which("duckdb")
DIAGNOSTIC = ROOT / "scripts/diagnostics/pricing_population_accounting.sql"
QUESTION = ROOT / "metabase/questions/73_fall2025_pricing_catalog_populations.sql"
EXAMPLES_QUESTION = ROOT / "metabase/questions/74_fall2025_pricing_catalog_examples.sql"


class PricingPopulationAccountingTest(unittest.TestCase):
    @unittest.skipIf(DUCKDB is None, "DuckDB CLI is required")
    def test_directions_and_population_boundaries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "fixture.duckdb"
            setup = """
                CREATE TABLE pricing_historical (
                  period_sortable VARCHAR, section_id VARCHAR, unit_id INTEGER,
                  isbn13 VARCHAR, dept_code VARCHAR, course_code VARCHAR,
                  section_code VARCHAR, crn VARCHAR, required BOOLEAN
                );
                INSERT INTO pricing_historical VALUES
                  ('2025-4','1::BIO::101::A::2025-4',1,'9780000000001','BIO','101','A','11',true),
                  ('2025-4','1::BIO::101::X::2025-4',1,'9780000000002','BIO','101','X','22',false),
                  ('2025-4','2::ART::1::A::2025-4',2,'9780000000003','ART','1','A','33',false),
                  ('2025-4','UNKNOWN::ART::1::A::2025-4',NULL,'bad','ART','1','A','44',true),
                  ('2025-4','shared',8,'9780000000008','BIO','1','A','55',false),
                  ('2025-4','shared',9,'9780000000008','BIO','1','A','55',false),
                  ('2025-4','UNKNOWN::BIO::1::A::2025-4',NULL,'9780000000009','BIO','1','A','66',true);
                CREATE TABLE course_material (
                  period_sortable VARCHAR, section_id VARCHAR, unit_id BIGINT, isbn13 BIGINT,
                  is_recent BOOLEAN, is_course_material_use BOOLEAN,
                  is_course_material_no_use BOOLEAN, source_row_count BIGINT,
                  is_supply BOOLEAN, no_details BOOLEAN, no_materials BOOLEAN, is_canada BOOLEAN
                );
                INSERT INTO course_material VALUES
                  ('2025-4','1::BIO::101::A::2025-4',1,9780000000001,true,true,false,2,false,false,false,false),
                  ('2025-4','1::BIO::101::B::2025-4',1,9780000000002,true,true,false,1,false,false,false,false),
                  ('2025-4','1::BIO::101::C::2025-4',1,9780000000004,true,false,true,3,true,false,false,false),
                  ('2025-4','UNKNOWN::BIO::1::A::2025-4',NULL,9780000000009,true,true,false,1,false,false,false,false),
                  ('2022-4','1::BIO::101::D::2022-4',1,9780000000005,false,false,false,1,false,false,false,false);
                CREATE TABLE comprehensive_data AS
                SELECT period_sortable, section_id FROM course_material;
            """
            subprocess.run([DUCKDB, str(database)], input=setup, text=True, check=True)
            result = subprocess.run(
                [DUCKDB, "-bail", "-readonly", "-csv", str(database)],
                input=DIAGNOSTIC.read_text(), text=True, capture_output=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("pricing_to_catalog,2025-4,exact catalog Use,2,2,2,0", result.stdout)
            self.assertIn(
                "pricing_to_catalog,2025-4,institution/term/ISBN candidate to Use,1,1,0,0",
                result.stdout,
            )
            self.assertIn(
                "pricing_to_catalog,2025-4,no catalog institution/term/ISBN counterpart,1,1,0,0",
                result.stdout,
            )
            self.assertIn(
                "pricing_to_catalog,2025-4,invalid unmatched pricing key,2,3,1,0",
                result.stdout,
            )
            self.assertIn(
                "catalog_to_pricing,2025-4,Use,institution/term/ISBN candidate,1,1,0",
                result.stdout,
            )
            self.assertIn("canonical_grouping_and_filtering,2025-4,4,7,3,1", result.stdout)
            self.assertIn("outside recent window", result.stdout)
            self.assertIn("institution_term_isbn_candidate_examples", result.stdout)

            question_sql = "\n".join(
                line for line in QUESTION.read_text().splitlines()
                if not line.startswith("-- ")
            )
            report = subprocess.run(
                [DUCKDB, "-bail", "-readonly", "-csv", str(database)],
                input=question_sql, text=True, capture_output=True, check=False,
            )
            self.assertEqual(report.returncode, 0, report.stderr)
            self.assertIn('"pricing → catalog",exact catalog Use,2,2,2,0', report.stdout)
            self.assertIn(
                '"canonical Use → pricing",institution/term/ISBN candidate,1,1,,0',
                report.stdout,
            )

            examples_sql = "\n".join(
                line for line in EXAMPLES_QUESTION.read_text().splitlines()
                if not line.startswith("-- ")
            )
            examples = subprocess.run(
                [DUCKDB, "-bail", "-readonly", "-csv", str(database)],
                input=examples_sql, text=True, capture_output=True, check=False,
            )
            self.assertEqual(examples.returncode, 0, examples.stderr)
            self.assertIn(
                "1,9780000000002,BIO,101,X,22,1::BIO::101::X::2025-4,1,1,1,1,1,1,1",
                examples.stdout,
            )
            self.assertNotIn("2::ART::1::A::2025-4", examples.stdout)


if __name__ == "__main__":
    unittest.main()
