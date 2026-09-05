#!/usr/bin/env python3
"""Check agreed data-flow boundaries in the stakeholder diagram."""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent


class FlowDiagramTest(unittest.TestCase):
    def setUp(self):
        document = (ROOT / "CMM-DATA-FLOW.md").read_text()
        self.chart = re.findall(r"```mermaid\n(.*?)```", document, re.S)[0]

    def group(self, name):
        match = re.search(rf"subgraph {name}\[.*?\n(.*?)\n    end", self.chart, re.S)
        self.assertIsNotNone(match, name)
        return match.group(1)

    def test_placement_and_provisional_outputs(self):
        self.assertIn('panel_email("panel_email<br/>(panel_20260108.csv)")', self.group("sources"))
        self.assertNotIn("panel_email", self.group("mailing"))
        self.assertNotIn("panel_email", self.group("helpers"))
        self.assertIn('master_course{{"master_course"}}', self.group("release"))
        self.assertIn('master_institution("master_institution")', self.group("release"))
        for name in ("master_course", "master_institution"):
            self.assertIn(f"master_section -.-> {name}", self.chart)
            self.assertRegex(self.chart, rf"class [^;]*\b{name}\b[^;]* expected;")

    def test_inherited_release_path_and_catalog_helper(self):
        for edge in (
            "course_material --> materials_recent",
            "recent_period --> materials_recent",
            "recent_period --> current_mailing",
            "recent_period --> supply",
            "recent_period --> section_enrollment",
            "materials_recent --> materials_use",
            "materials_use --> master_material",
            "pricing_wide --> master_material",
            "master_material --> master_section",
            "catalog --> section_enrollment",
            "section_enrollment --> comprehensive",
            "ipeds --> comprehensive",
        ):
            self.assertIn(edge, self.chart)
        for edge in (
            "course_material --> master_section",
            "pricing_wide --> master_institution",
            "ipeds --> section_enrollment",
            "supply --> section_enrollment",
        ):
            self.assertNotIn(edge, self.chart)


if __name__ == "__main__":
    unittest.main()
