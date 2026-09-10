#!/usr/bin/env python3
"""Focused actual-SQL fixture for Master Section audit and URL lineage."""

from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

import test_flow_pipeline


DUCKDB = test_flow_pipeline.DUCKDB
SQL = test_flow_pipeline.SQL
cli = test_flow_pipeline.cli
render = test_flow_pipeline.render


class SectionLineageTest(unittest.TestCase):
    @unittest.skipIf(DUCKDB is None, "DuckDB CLI is required")
    def test_section_audits_are_inherited_once_and_urls_stay_canonical(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "fixture.duckdb"
            cli(database, test_flow_pipeline.RenamedFlowPipelineTest.fixture_sql() + """
UPDATE pricing_historical
SET bookstore_url = CASE isbn13
    WHEN 9780000000001 THEN 'https://z.example'
    WHEN 9780000000002 THEN 'https://a.example'
END
WHERE isbn13 IN (9780000000001, 9780000000002);
INSERT INTO pricing_historical VALUES
  ('1::BIO::101::002::2025-4', 9780000000003, 1, true, 'Fixture U',
   'https://0-excluded.example', 'Lab Kit >supply<', 'C', 'P', NULL,
   'buy', 'new', 'physical', NULL, 5, '2025-4'),
  ('1::BIO::101::002::2025-4', 9780000000004, 1, false, 'Fixture U',
   'https://0-excluded.example', '*No Books Required*', NULL, NULL, NULL,
   'buy', 'new', 'physical', NULL, 5, '2025-4');
INSERT INTO course_catalog_20251215
SELECT * REPLACE (
    9780000000007 AS ISBN13,
    'Second Text' AS Title,
    '1::BIO::103' AS course_id,
    '1::BIO::103::001::2025-4' AS section_id
)
FROM course_catalog_20251215
WHERE ISBN13 = 9780000000002
LIMIT 1;
INSERT INTO pricing_historical VALUES
  ('1::BIO::103::001::2025-4', 9780000000007, 1, false, 'Fixture U',
   'https://z.example', 'Second Text', 'B', 'P', NULL,
   'buy', 'new', 'physical', NULL, 20, '2025-4');
INSERT INTO course_catalog_20251215
SELECT * REPLACE (
    9780000000008 AS ISBN13,
    'No Unit Text' AS Title,
    CAST(NULL AS BIGINT) AS unit_id,
    '1::BIO::104' AS course_id,
    '1::BIO::104::001::2025-4' AS section_id
)
FROM course_catalog_20251215
WHERE ISBN13 = 9780000000002
LIMIT 1;
INSERT INTO pricing_historical VALUES
  ('1::BIO::104::001::2025-4', 9780000000008, 1, false, 'Fixture U',
   'https://null-unit.example', 'No Unit Text', 'B', 'P', NULL,
   'buy', 'new', 'physical', NULL, 20, '2025-4');
""")

            for stage in (
                "0c_recent_period.sql",
                "1a_supply_classification.sql",
                "1b_section_enrollment.sql",
                "2_oer_classification.sql",
                "2b_course_material.sql",
                "2c_pricing_wide.sql",
                "3_mailing_lists.sql",
                "3b_master_material.sql",
                "4_merged_records.sql",
            ):
                cli(database, render(SQL / stage))
            cli(database, "CREATE TABLE master_institution AS\n" + render(SQL / "models/master_institution.sql"))

            # The first retained section has two Use items plus two excluded
            # supply/NoUse canonical items. Its audit counts are repeated on both Use items,
            # then selected once rather than summed by Master Section.
            self.assertEqual(cli(database, """
                SELECT COUNT(*), MIN(section_course_material_no_use_count),
                       MAX(section_course_material_no_use_count),
                       MIN(section_supply_count), MAX(section_supply_count),
                       BOOL_AND(NOT is_section_canada), BOOL_AND(is_section_supply)
                FROM master_material
                WHERE section_id = '1::BIO::101::002::2025-4'
            """), ["2,2,2,2,2,true,true"])
            self.assertEqual(cli(database, """
                SELECT material_count, course_material_no_use_count, no_materials_count,
                       supply_count, is_canada, is_supply
                FROM master_section
                WHERE section_id = '1::BIO::101::002::2025-4'
            """), ["2,2,1,2,false,true"])

            # Excluded priced rows do not enter Master Material or influence its
            # section URL; two canonical URLs tie, so lexical ordering chooses a.
            self.assertEqual(cli(database, """
                SELECT (SELECT COUNT(*) FROM pricing_wide
                        WHERE section_id = '1::BIO::101::002::2025-4'),
                       (SELECT COUNT(*) FROM master_material
                        WHERE section_id = '1::BIO::101::002::2025-4'),
                       (SELECT bookstore_url FROM master_section
                        WHERE section_id = '1::BIO::101::002::2025-4')
            """), ["4,2,https://a.example"])

            # Section URLs a and z tie at the institution, so its URL uses the
            # same lexical tie-break and has no direct pricing_wide dependency.
            self.assertEqual(cli(database, """
                SELECT bookstore_url FROM master_institution
                WHERE period_sortable = '2025-4' AND unit_id = 1
            """), ["https://a.example"])
            self.assertEqual(cli(database, """
                SELECT COUNT(*) FROM master_section
                WHERE section_id = '1::BIO::104::001::2025-4' AND unit_id IS NULL
            """), ["1"])
            self.assertEqual(cli(database, """
                SELECT COALESCE(bookstore_url, '<null>') FROM master_institution
                WHERE period_sortable = '2025-4' AND unit_id IS NULL
            """), ["<null>"])

            # The production value paths have no direct source-side audit or
            # pricing joins after their canonical handoffs.
            self.assertNotIn(
                "FROM course_material c",
                (SQL / "4_merged_records.sql").read_text(),
            )
            self.assertNotIn(
                "pricing_wide",
                (SQL / "models/master_institution.sql").read_text(),
            )


if __name__ == "__main__":
    unittest.main()
