#!/usr/bin/env python3
"""Static contract checks for the deterministic 10% material sample."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent
SQL = ROOT / "scripts/sql"


class Sample10ContractTest(unittest.TestCase):
    def test_membership_model_precedes_material_model(self) -> None:
        models = sorted(path.name for path in (SQL / "models").glob("*.sql"))
        self.assertLess(
            models.index("sample10_section_ids.sql"),
            models.index("sample10pct_materials.sql"),
        )

    def test_material_model_uses_canonical_membership(self) -> None:
        query = (SQL / "models/sample10pct_materials.sql").read_text()
        self.assertIn("FROM material_costs material", query)
        self.assertIn("JOIN sample10_section_ids sample", query)
        self.assertIn("USING (period_sortable, section_id)", query)
        self.assertNotIn("md5(", query.lower())

    def test_export_replaces_sampled_master_section(self) -> None:
        current = SQL / "exports/34_sample10pct_materials.sql"
        retired = SQL / "exports/34_master_section_sample10pct.sql"
        self.assertTrue(current.is_file())
        self.assertFalse(retired.exists())
        self.assertIn("FROM sample10pct_materials", current.read_text())

    def test_reconciliation_consumes_materialized_sample(self) -> None:
        query = (SQL / "exports/37_sample10_reconciliation.sql").read_text()
        self.assertIn("FROM material_costs", query)
        self.assertIn("FROM sample10pct_materials", query)


if __name__ == "__main__":
    unittest.main()
