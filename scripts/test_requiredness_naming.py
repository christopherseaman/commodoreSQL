#!/usr/bin/env python3
"""Requiredness booleans use the agreed is_* vocabulary."""

from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parent.parent
SQL_ROOT = REPO_ROOT / "scripts/sql"


class RequirednessNamingTest(unittest.TestCase):
    def test_derived_requiredness_aliases_use_is_prefix(self) -> None:
        sql = "\n".join(path.read_text() for path in SQL_ROOT.rglob("*.sql"))
        for alias in (
            "has_required",
            "has_book_status_required",
            "has_book_status_optional_recommended",
            "has_required_raw",
            "raw_required",
            "legacy_is_required_direct",
        ):
            with self.subTest(alias=alias):
                self.assertIsNone(
                    re.search(rf"\bAS\s+{alias}\b", sql, re.IGNORECASE),
                )

    def test_direct_and_inferred_names_are_present(self) -> None:
        comprehensive = (SQL_ROOT / "2_oer_classification.sql").read_text()
        section = (SQL_ROOT / "1b_section_enrollment.sql").read_text()
        self.assertIn("AS is_required_direct", section)
        self.assertIn("AS is_required_direct", comprehensive)
        self.assertIn("AS is_required_inferred", comprehensive)


if __name__ == "__main__":
    unittest.main()
