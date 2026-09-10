#!/usr/bin/env python3
"""Static contract checks for the deterministic 10% material sample."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent
SQL = ROOT / "scripts/sql"


class Sample10ContractTest(unittest.TestCase):
    def test_material_model_is_the_only_sample_model(self) -> None:
        models = sorted(path.name for path in (SQL / "models").glob("*.sql"))
        self.assertIn("sample_material_10pct.sql", models)
        self.assertNotIn("sample10_section_ids.sql", models)

    def test_material_model_uses_canonical_hash_membership(self) -> None:
        query = (SQL / "models/sample_material_10pct.sql").read_text()
        self.assertIn("FROM master_material material", query)
        self.assertIn("LEFT(md5(material.section_id), 16)", query)
        self.assertIn("AS UBIGINT) % 10 = 0", query)
        self.assertNotIn("sample10_section_ids", query)

    def test_export_replaces_sampled_master_section(self) -> None:
        current = SQL / "exports/34_sample_material_10pct.sql"
        retired = SQL / "exports/34_master_section_sample10pct.sql"
        self.assertTrue(current.is_file())
        self.assertFalse(retired.exists())
        self.assertIn("FROM sample_material_10pct", current.read_text())

    def test_reconciliation_consumes_materialized_sample(self) -> None:
        query = (SQL / "exports/37_sample10_reconciliation.sql").read_text()
        self.assertIn("FROM master_material", query)
        self.assertIn("FROM sample_material_10pct", query)
        self.assertIn("FROM full_section_context", query)
        self.assertIn("FROM comprehensive_data", query)
        self.assertIn("section_enrollment_assigned AS enrollment_assigned", query)
        self.assertIn("LEFT(md5(section_id), 16)", query)
        self.assertIn("c.is_recent", query)
        self.assertNotIn("is_post_2024", query)
        self.assertNotIn("period_date >= DATE '2024-01-01'", query)
        self.assertNotIn("sample10_section_ids", query)
        self.assertNotIn("section_cost", query)


if __name__ == "__main__":
    unittest.main()
