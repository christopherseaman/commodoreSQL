#!/usr/bin/env python3
"""Actual-SQL contract for the shared newest-twelve catalog-term window."""

from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

import test_flow_pipeline


class RecentMaterialTest(unittest.TestCase):
    @unittest.skipIf(test_flow_pipeline.DUCKDB is None, "DuckDB CLI is required")
    def test_catalog_window_drives_materials_and_mailing(self) -> None:
        terms = [
            "2025-3", "2025-2", "2025-1", "2024-4", "2024-3", "2024-2",
            "2024-1", "2023-4", "2023-3", "2023-2", "2023-1", "2022-4",
        ]
        inserts = []
        for index, term in enumerate(terms, start=10):
            year, quarter = term.split("-")
            inserts.append(f"""
INSERT INTO course_catalog_20251215
SELECT * REPLACE (
    {9780000000100 + index} AS ISBN13,
    {"'Lab Kit >supply<'" if term == '2023-3' else "'Historical Text'"} AS Title,
    'required' AS book_status,
    '1::H::{index}' AS course_id,
    '1::H::{index}::A::{term}' AS section_id,
    '{term}' AS period_sortable,
    DATE '{year}-{(int(quarter) - 1) * 3 + 1:02d}-01' AS period_date,
    'teacher{index}@example.edu' AS email
)
FROM course_catalog_20251215
WHERE ISBN13 = 9780000000001
LIMIT 1;
""")
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "fixture.duckdb"
            test_flow_pipeline.cli(database, test_flow_pipeline.RenamedFlowPipelineTest.fixture_sql() + "".join(inserts) + """
-- Duplicate and NULL catalog terms cannot expand the shared term window.
INSERT INTO course_catalog_20251215
SELECT * FROM course_catalog_20251215
WHERE period_sortable = '2023-4'
LIMIT 1;
INSERT INTO course_catalog_20251215
SELECT * REPLACE (9780000000888 AS ISBN13, NULL AS section_id,
                  NULL AS period_sortable, NULL AS period_date,
                  'null-term@example.edu' AS email)
FROM course_catalog_20251215
WHERE ISBN13 = 9780000000001
LIMIT 1;
""")
            for stage in (
                "0c_recent_period.sql", "1a_supply_classification.sql",
                "1b_section_enrollment.sql", "2_oer_classification.sql",
                "2b_course_material.sql", "3_mailing_lists.sql",
            ):
                test_flow_pipeline.cli(database, test_flow_pipeline.render(test_flow_pipeline.SQL / stage))
            self.assertEqual(test_flow_pipeline.cli(database, """
                SELECT COUNT(*), MIN(period_sortable), MAX(period_sortable) FROM recent_period;
                SELECT is_recent, is_course_material_use, is_required_inferred
                FROM comprehensive_data WHERE period_sortable = '2023-4' LIMIT 1;
                SELECT is_recent, is_supply, is_course_material_use,
                       is_course_material_no_use, is_required_inferred
                FROM comprehensive_data WHERE period_sortable = '2023-3' LIMIT 1;
                SELECT section_enrollment_assigned, section_enrollment_source
                FROM comprehensive_data WHERE period_sortable = '2023-4' LIMIT 1;
                SELECT is_recent, is_course_material_use FROM comprehensive_data
                WHERE period_sortable = '2022-4' LIMIT 1;
                SELECT COUNT(*) = (SELECT COUNT(*) FROM course_material_use)
                               + (SELECT COUNT(*) FROM course_material_no_use)
                FROM course_material_recent;
                SELECT COUNT(DISTINCT period_sortable) FROM current_mailing;
                SELECT COUNT(*) FROM recent_period
                WHERE period_sortable IS NULL;
            """), [
                "12,2023-1,2025-4", "true,true,true", "true,true,false,true,false",
                "30,own", "false,false", "true", "12", "0",
            ])
            test_flow_pipeline.cli(database, """
INSERT INTO course_catalog_20251215
SELECT * REPLACE (9780000000999 AS ISBN13, 'New Text' AS Title,
  '1::N::999' AS course_id, '1::N::999::A::2026-1' AS section_id,
  '2026-1' AS period_sortable, DATE '2026-03-01' AS period_date,
  'new@example.edu' AS email)
FROM course_catalog_20251215 WHERE ISBN13 = 9780000000001 LIMIT 1;
""")
            for stage in (
                "0c_recent_period.sql", "1a_supply_classification.sql",
                "1b_section_enrollment.sql", "2_oer_classification.sql",
                "2b_course_material.sql", "3_mailing_lists.sql",
            ):
                test_flow_pipeline.cli(database, test_flow_pipeline.render(test_flow_pipeline.SQL / stage))
            self.assertEqual(test_flow_pipeline.cli(database, """
                SELECT COUNT(*), MIN(period_sortable), MAX(period_sortable) FROM recent_period;
                SELECT is_recent, is_course_material_use, is_required_inferred
                FROM comprehensive_data WHERE period_sortable = '2026-1' LIMIT 1;
                SELECT is_recent, is_course_material_use, is_course_material_no_use
                FROM comprehensive_data WHERE period_sortable = '2023-1' LIMIT 1;
                SELECT COUNT(*) FROM course_material_recent WHERE period_sortable = '2023-1';
                SELECT COUNT(*) FROM course_material_use WHERE period_sortable = '2023-1';
                SELECT COUNT(*) FROM current_mailing WHERE period_sortable = '2023-1';
                SELECT COUNT(*) FROM course_material WHERE period_sortable = '2023-1';
                SELECT COUNT(*) FROM (
                    (SELECT period_sortable FROM recent_period
                     EXCEPT SELECT DISTINCT period_sortable FROM course_material_recent)
                    UNION ALL
                    (SELECT DISTINCT period_sortable FROM course_material_recent
                     EXCEPT SELECT period_sortable FROM recent_period)
                );
                SELECT COUNT(*) FROM (
                    (SELECT period_sortable FROM recent_period
                     EXCEPT SELECT DISTINCT period_sortable FROM current_mailing)
                    UNION ALL
                    (SELECT DISTINCT period_sortable FROM current_mailing
                     EXCEPT SELECT period_sortable FROM recent_period)
                );
            """), [
                "12,2023-2,2026-1", "true,true,true", "false,false,false",
                "0", "0", "0", "1", "0", "0",
            ])


if __name__ == "__main__":
    unittest.main()
