#!/usr/bin/env python3
"""Check agreed data-flow boundaries in the stakeholder diagram."""

from pathlib import Path
import csv
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent


class FlowDiagramTest(unittest.TestCase):
    def setUp(self):
        self.document = (ROOT / "CMM-DATA-FLOW.md").read_text()
        self.chart = re.findall(r"```mermaid\n(.*?)```", self.document, re.S)[0]

    def test_walkthrough_structure_and_retained_grains(self):
        self.assertEqual(
            re.findall(r"^## (.+)$", self.document, re.M),
            ["Sources", "Logic", "Samples & exports"],
        )
        logic = self.document.split("## Logic\n", 1)[1].split("## Samples & exports", 1)[0]
        self.assertEqual(
            re.findall(r"^### (.+)$", logic, re.M),
            ["Helpers", "Materials", "Pricing", "Mailing", "Release"],
        )
        self.assertIn('comprehensive("comprehensive_data")', self.chart)
        self.assertIn('course_material("course_material")', self.chart)
        self.assertIn("comprehensive --> course_material", self.chart)
        self.assertNotIn("## Table logic", self.document)

    def test_table_subsections_follow_diagram_areas(self):
        expected = {
            "Helpers": ["recent_period", "supply_isbn_classification", "section_enrollment"],
            "Materials": ["comprehensive_data", "course_material", "course_material_recent",
                          "course_material_use", "course_material_no_use"],
            "Pricing": ["pricing_wide"],
            "Mailing": ["master_mailing"],
            "Release": ["master_material", "master_section", "master_isbn", "master_course",
                        "master_institution", "current_mailing"],
        }
        logic = self.document.split("## Logic\n", 1)[1].split("## Samples & exports", 1)[0]
        for area, tables in expected.items():
            section = re.search(rf"^### {area}\n(.*?)(?=^### |\Z)", logic, re.M | re.S)
            self.assertIsNotNone(section, area)
            self.assertEqual(re.findall(r"^#### (.+)$", section.group(1), re.M), tables)
        with (ROOT / "docs/data-dictionary.tsv").open(newline="") as handle:
            relations = {row["relation"] for row in csv.DictReader(handle, delimiter="\t")}
        headings = re.findall(r"^#{3,4} (.+)$", self.document, re.M)
        for relation in relations:
            self.assertEqual(headings.count(relation), 1, relation)

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

        exports = re.findall(r"```mermaid\n(.*?)```", self.document, re.S)[1]
        for name in ("course_files", "institution_files"):
            self.assertRegex(exports, rf"class [^;]*\b{name}\b[^;]* provisionalFile;")
        self.assertIn("classDef provisionalFile fill:#fff2cc", exports)
        self.assertIn('sample_unit_100id["sample_unit_100id<br/>(100 institution list)"]', exports)
        self.assertNotIn("25id", exports)
        self.assertNotRegex(self.document, r"\bsample25_\w+")

    def test_logic_tables_use_standard_outline(self):
        sources = self.document.split("## Sources\n", 1)[1].split("### Pending inputs", 1)[0]
        logic = self.document.split("## Logic\n", 1)[1].split("## Samples & exports", 1)[0]
        samples = self.document.split("### Samples\n", 1)[1].split("### Analysis subsets", 1)[0]
        sections = re.findall(
            r"^#{3,4} ([^\n]+)\n(.*?)(?=^#{3,4} |\Z)", sources + logic + samples, re.M | re.S
        )
        area_headings = {"Lookups", "Helpers", "Materials", "Pricing", "Mailing", "Release"}
        sections = [(name, body) for name, body in sections if name not in area_headings]
        self.assertTrue(sections)
        expected = ["Unit of analysis (group by)", "Joins", "Filters (WHERE/HAVING)", "Derivations"]
        for name, body in sections:
            labels = re.findall(r"^- \*\*(.+?):\*\*", body, re.M)
            self.assertEqual(labels, expected, name)

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
            "panel_email --> comprehensive",
            "optout --> comprehensive",
        ):
            self.assertNotIn(edge, self.chart)


if __name__ == "__main__":
    unittest.main()
