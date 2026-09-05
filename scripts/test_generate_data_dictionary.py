#!/usr/bin/env python3
"""Tests for the deterministic split data-dictionary generator."""

from __future__ import annotations

import importlib.util
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA = REPO_ROOT / "schema.dbml"
APPENDIX = REPO_ROOT / "MASTER-SECTION-DICTIONARY.md"
OUTPUT = REPO_ROOT / "DATA-DICTIONARY.md"
DOCS_DIRECTORY = REPO_ROOT / "docs/data-dictionary"
GENERATOR_PATH = REPO_ROOT / "scripts/generate_data_dictionary.py"
SPEC = importlib.util.spec_from_file_location("generate_data_dictionary", GENERATOR_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"could not import {GENERATOR_PATH}")
generator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = generator
SPEC.loader.exec_module(generator)


TABLE_HEADER = (
    "| Column | Type | Example / structure | "
    "Direct upstream source / derivation | Description |"
)


def _body(text: str) -> str:
    if not text.startswith("---\n"):
        return text
    closing = text.find("\n---\n", 4)
    if closing < 0:
        raise AssertionError("unterminated test frontmatter")
    return text[closing + len("\n---\n") :].lstrip()


def _table_rows(text: str) -> list[list[str]]:
    lines = _body(text).splitlines()
    start = lines.index(TABLE_HEADER)
    rows: list[list[str]] = []
    for line in lines[start + 2 :]:
        if not line.startswith("|"):
            break
        cells = [
            cell.strip().replace("\\|", "|")
            for cell in re.split(r"(?<!\\)\|", line.strip().strip("|"))
        ]
        if len(cells) != 5:
            raise AssertionError(f"unexpected generated row: {line!r}")
        rows.append(cells)
    return rows


class DataDictionaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.relations = generator.parse_dbml(SCHEMA)
        cls.by_name = {relation.name: relation for relation in cls.relations}
        cls.index = OUTPUT.read_text(encoding="utf-8")
        cls.docs = {
            path.stem: path.read_text(encoding="utf-8")
            for path in DOCS_DIRECTORY.glob("*.md")
        }
        cls.appendix_body = APPENDIX.read_text(encoding="utf-8")
        cls.field_metadata = generator.resolve_field_metadata(
            cls.relations, cls.appendix_body
        )

    def test_canonical_scope_is_33_relations_and_1199_fields(self) -> None:
        self.assertEqual(len(self.relations), 33)
        self.assertEqual(sum(r.kind == "table" for r in self.relations), 26)
        self.assertEqual(sum(r.kind == "view" for r in self.relations), 7)
        field_count = sum(len(relation.columns) for relation in self.relations)
        self.assertEqual(field_count, 1_199)

    def test_one_deterministically_named_document_per_relation(self) -> None:
        expected_names = {relation.name for relation in self.relations}
        self.assertEqual(set(self.docs), expected_names)
        self.assertEqual(len(self.docs), 33)
        self.assertEqual(
            {path.name for path in DOCS_DIRECTORY.glob("*.md")},
            {f"{name}.md" for name in expected_names},
        )

    def test_index_is_concise_and_links_every_relation_once(self) -> None:
        body = _body(self.index)
        self.assertEqual(body.count("| Relation | Kind | Grain / key | Stage |"), 6)
        self.assertIn("## External source tables (5 relations)", body)
        self.assertIn("## Lookup/reference inputs (2 relations)", body)
        self.assertIn("## Processing helpers (5 relations)", body)
        self.assertIn("## Canonical outputs (12 relations)", body)
        self.assertIn("## Data-quality sidecars (7 relations)", body)
        self.assertIn("## Report/export views (2 relations)", body)
        self.assertIn("not database relations or dictionary pages", body)
        self.assertEqual(
            {name for _, _, names in generator.RELATION_GROUPS for name in names},
            {relation.name for relation in self.relations},
        )
        self.assertNotIn("## Relation columns", body)
        self.assertNotIn("Population / denominator", body)
        for relation in self.relations:
            metadata = generator.RELATION_METADATA[relation.name]
            link = (
                f"| [`{relation.name}`](docs/data-dictionary/{relation.name}.md) | "
                f"{relation.kind} | {metadata.grain} | {metadata.stage} |"
            )
            with self.subTest(relation=relation.name):
                self.assertEqual(body.count(link), 1)
        self.assertEqual(body.count(generator.NOTION_CHILD_CONTAINER), 1)
        self.assertTrue(body.rstrip().endswith(generator.NOTION_CHILD_CONTAINER))
        self.assertNotIn(generator.NOTION_CHILD_CONTAINER, "\n".join(self.docs.values()))

    def test_each_relation_document_has_metadata_and_exactly_one_table(self) -> None:
        for relation in self.relations:
            body = _body(self.docs[relation.name])
            metadata = generator.RELATION_METADATA[relation.name]
            with self.subTest(relation=relation.name):
                self.assertTrue(body.startswith(generator.GENERATED_MARKER))
                self.assertEqual(
                    body.count(f"# `{relation.name}` data dictionary\n"), 1
                )
                self.assertIn(f"- Relation kind: {relation.kind}\n", body)
                self.assertIn(f"- Grain / key: {metadata.grain}\n", body)
                self.assertIn(f"- Pipeline stage: {metadata.stage}\n", body)
                self.assertIn("- Direct upstream relations:", body)
                self.assertEqual(body.count(TABLE_HEADER), 1)
                self.assertEqual(body.count("|---|---|---|---|---|"), 1)

    def test_field_rows_preserve_exact_schema_order_and_types(self) -> None:
        total_rows = 0
        for relation in self.relations:
            rows = _table_rows(self.docs[relation.name])
            expected = [
                (f"`{column.name}`", f"`{column.data_type}`")
                for column in relation.columns
            ]
            actual = [(row[0], row[1]) for row in rows]
            with self.subTest(relation=relation.name):
                self.assertEqual(actual, expected)
                self.assertEqual(len(rows), len(relation.columns))
                self.assertEqual(len({row[0] for row in rows}), len(rows))
            total_rows += len(rows)
        self.assertEqual(total_rows, 1_199)

    def test_sample_materials_preserve_material_costs_schema(self) -> None:
        material = self.by_name["master_material"]
        sample = self.by_name["sample_material_10pct"]
        self.assertEqual(
            [(column.name, column.data_type) for column in sample.columns],
            [(column.name, column.data_type) for column in material.columns],
        )
        for column in sample.columns:
            metadata = self.field_metadata[(sample.name, column.name)]
            self.assertEqual(
                metadata.source,
                f"`master_material.{column.name}` retained after the deterministic section-hash filter.",
            )

    def test_every_field_has_example_source_and_short_conceptual_description(self) -> None:
        banned_descriptions = {
            "String value for this field.",
            "Numeric value for this field.",
            "Value stored in this column.",
            "Field value associated with this record.",
        }
        for relation in self.relations:
            for column, row in zip(
                relation.columns, _table_rows(self.docs[relation.name]), strict=True
            ):
                example, source, description = row[2:]
                with self.subTest(relation=relation.name, column=column.name):
                    self.assertTrue(example)
                    self.assertTrue(source)
                    self.assertNotEqual(
                        source,
                        generator._upstream(generator.RELATION_METADATA[relation.name]),
                    )
                    self.assertNotIn("Relation upstream (not field-specific)", source)
                    self.assertTrue(description)
                    self.assertEqual(
                        description,
                        self.field_metadata[(relation.name, column.name)].description,
                    )
                    self.assertNotIn(description, banned_descriptions)
                    self.assertGreaterEqual(generator.description_word_count(description), 5)
                    self.assertLessEqual(generator.description_word_count(description), 10)
                    lowered = description.lower()
                    for fragment in generator._BANNED_DESCRIPTION_FRAGMENTS:
                        self.assertNotIn(fragment, lowered)
        self.assertEqual(
            len({column.name for relation in self.relations for column in relation.columns}),
            298,
        )

    def test_representative_descriptions_are_conceptual_and_relation_aware(self) -> None:
        expected = {
            ("course_catalog_20251215", "Title"): "Title supplied for the adopted course material.",
            ("course_catalog_20251215", "section_id"): "Period-specific identifier for the distinct section offering.",
            ("comprehensive_data", "institution_name"): "Canonical institution name supplied by IPEDS.",
            ("course_material", "source_row_count"): "Catalog rows collapsed into the canonical material item.",
            ("course_material", "catalog_metadata_conflict"): "Flags conflicting bibliographic values among grouped catalog rows.",
            ("master_mailing", "email"): "Normalized instructor email used for contact and matching.",
            ("pricing_historical", "price"): "Observed amount for the specific pricing offering.",
            ("section_enrollment", "enrollment_assigned"): "Best available section enrollment from the assignment ladder.",
            ("master_course", "required_cost_owned_avg"): "Mean buy-only required-cost midpoint across course sections.",
            ("__data_quality_metrics", "metric_value"): "Scalar result identified by its three metric keys.",
        }
        for key, description in expected.items():
            with self.subTest(field=".".join(key)):
                self.assertEqual(self.field_metadata[key].description, description)

    def test_audited_panel_enrollment_and_opt_out_contracts(self) -> None:
        panel = self.field_metadata[("panel", "response_year")]
        panel_latest = self.field_metadata[("panel_email", "panel_response_year")]
        self.assertIn("OER_YYYY", panel.values)
        self.assertIn("OER_2018", panel.values)
        self.assertIn("campaign label", panel.description)
        self.assertIn("OER_2025", panel_latest.values)
        self.assertIn("campaign label", panel_latest.description)
        self.assertNotIn("Four-digit response year", panel.values)

        expected_noise_structures = {
            ("section_enrollment", "enrollment_assigned"): "raw negatives can propagate",
            ("master_course", "enrollment_total"): "source negatives may propagate",
            ("master_course", "seats_taken_total"): "source noise and sentinels may propagate",
            ("master_institution", "enrollments_tot"): "negative source values may propagate",
            ("master_institution", "seats_taken_tot"): "negative source values may propagate",
            ("master_isbn", "enroll_tot"): "negative source values may propagate",
        }
        for key, phrase in expected_noise_structures.items():
            with self.subTest(field=".".join(key)):
                self.assertIn(phrase, self.field_metadata[key].values)
                self.assertNotIn("Non-negative", self.field_metadata[key].values)

        opt_out = generator.RELATION_METADATA["opt_out"]
        self.assertEqual(
            opt_out.grain,
            "One normalized opt-out source row; cleaned email may repeat on refresh",
        )
        self.assertIn("source rows", opt_out.intended_use)
        self.assertEqual(
            self.field_metadata[("opt_out", "email")].description,
            "Normalized email address listed for mailing opt-out.",
        )

    def test_passthrough_and_inherited_sources_name_the_source_column(self) -> None:
        for (relation_name, column_name), item in self.field_metadata.items():
            if item.metadata_kind not in {"passthrough", "inherited"}:
                continue
            with self.subTest(relation=relation_name, column=column_name):
                self.assertRegex(
                    item.source,
                    rf"`[A-Za-z_][A-Za-z0-9_]*\.{re.escape(column_name)}`",
                )

    def test_examples_retain_important_value_conventions(self) -> None:
        examples = {
            (relation.name, row[0].strip("`")): row[2]
            for relation in self.relations
            for row in _table_rows(self.docs[relation.name])
        }
        self.assertIn("YYYY-N", examples[("course_material", "period_sortable")])
        self.assertIn("TRUE or FALSE", examples[("course_material", "is_oer")])
        self.assertIn(
            "Non-negative whole-number count",
            examples[("course_material", "source_row_count")],
        )
        self.assertIn("USD amount", examples[("pricing_historical", "price")])
        self.assertIn("DECIMAL(10,2)", examples[("pricing_historical", "price")])
        self.assertIn("ISBN", examples[("pricing_historical", "isbn13")])
        self.assertIn("Lowercase, trimmed", examples[("current_mailing", "email")])
        self.assertNotIn("VARCHAR or NULL", "\n".join(examples.values()))
        rendered_examples = "\n".join(examples.values())
        for generic in (
            "spelling/casing follows the stated source or derivation",
            "Whole number in the declared integer range",
            "Decimal measure in the units named by the field",
        ):
            self.assertNotIn(generic, rendered_examples)
        self.assertIn(
            "Signed BIGINT keyed by",
            examples[("__data_quality_metrics", "metric_value")],
        )
        self.assertIn("midpoint", examples[("pricing_wide", "price_avg")])
        self.assertIn(
            "mean of section-level buy-only cost midpoints",
            examples[("master_course", "required_cost_owned_avg")],
        )

    def test_old_four_part_prose_columns_are_absent(self) -> None:
        generated = self.index + "\n" + "\n".join(self.docs.values())
        for old_header in (
            "Source / derivation",
            "Values / format",
            "Population / denominator",
            "NULL meaning",
        ):
            self.assertNotIn(f"| {old_header} |", generated)

    def test_master_section_appendix_is_linked_and_not_embedded(self) -> None:
        index_body = _body(self.index)
        master_body = _body(self.docs["master_section"])
        self.assertIn("(MASTER-SECTION-DICTIONARY.md)", index_body)
        self.assertIn("(../../MASTER-SECTION-DICTIONARY.md)", master_body)
        self.assertNotIn("# Master Section release dictionary", index_body)
        self.assertNotIn("## Reading rules", master_body)

    def test_registry_and_field_contract_exactly_cover_schema(self) -> None:
        expected_relations = {relation.name for relation in self.relations}
        expected_fields = {
            (relation.name, column.name)
            for relation in self.relations
            for column in relation.columns
        }
        self.assertEqual(set(generator.RELATION_METADATA), expected_relations)
        self.assertEqual(set(self.field_metadata), expected_fields)

    def test_select_star_view_schemas_and_sources_match_bases(self) -> None:
        for view_name, base_name in generator.INHERITED_VIEW_BASES.items():
            view = self.by_name[view_name]
            base = self.by_name[base_name]
            with self.subTest(view=view_name, base=base_name):
                self.assertEqual(view.kind, "view")
                self.assertEqual(
                    [(column.name, column.data_type) for column in view.columns],
                    [(column.name, column.data_type) for column in base.columns],
                )
                for column in view.columns:
                    source = self.field_metadata[(view_name, column.name)].source
                    self.assertIn(f"`{base_name}.{column.name}`", source)

    def test_reviewed_semantic_contracts_match_executable_sql(self) -> None:
        self.assertEqual(
            generator.RELATION_METADATA["current_mailing"].stage,
            "Release / 3_mailing_lists.sql",
        )
        master_course = self.by_name["master_course"]
        types = {column.name: column.data_type for column in master_course.columns}
        for name in (
            "has_enrollment_sections",
            "has_enrollment_sibling_sections",
            "has_enrollment_own_seats_sections",
            "has_enrollment_sibling_seats_sections",
        ):
            self.assertEqual(types[name], "bigint")
            self.assertIn("Course sections", self.field_metadata[("master_course", name)].description)

        format_count = self.field_metadata[("pricing_wide", "format_count")].source
        self.assertIn("COUNT(DISTINCT (pricing_historical.book_option", format_count)
        self.assertIn("COALESCE(pricing_historical.book_condition,'na')", format_count)
        self.assertIn("COALESCE(pricing_historical.book_format,'na')", format_count)
        instructor = self.field_metadata[("pricing_historical", "instructor_name")].source
        self.assertIn("STRING_AGG(DISTINCT", instructor)
        self.assertIn("ORDER BY", instructor)
        for name in ("rental_days_min", "rental_days_max"):
            self.assertIn(
                "book_option='rental'",
                self.field_metadata[("pricing_wide", name)].source,
            )
        self.assertIn(
            "May be NULL",
            self.field_metadata[("pricing_wide", "isbn13")].null_meaning,
        )

        for status in ("required", "optional"):
            for scope in ("total", "owned"):
                for bound in ("min", "max"):
                    name = f"{status}_cost_{scope}_{bound}"
                    self.assertIn(
                        f"master_section.{name}",
                        self.field_metadata[("master_course", name)].source,
                    )
        owned_avg = self.field_metadata[("master_course", "required_cost_owned_avg")]
        self.assertIn("master_section.required_cost_owned_min", owned_avg.source)
        self.assertIn("master_section.required_cost_owned_max", owned_avg.source)
        self.assertNotIn("required_cost_owned_midpoint", owned_avg.source)
        self.assertIn("midpoint", owned_avg.description)

    def test_dq_immediate_upstreams_and_keyed_derivations_are_precise(self) -> None:
        expected_upstreams = {
            "__data_quality_metrics": (
                "comprehensive_data", "pricing_historical", "pricing_wide",
                "${PRICING_CSV}",
            ),
            "__data_quality_top_unmatched_ipeds_schools": ("comprehensive_data",),
            "__data_quality_null_isbn_breakdown": ("comprehensive_data",),
            "__data_quality_top_null_isbn_schools": ("comprehensive_data",),
            "__data_quality_pricing_match_by_period": (
                "pricing_historical", "comprehensive_data",
            ),
            "__data_quality_top_unmatched_pricing_sections": (
                "pricing_historical", "comprehensive_data",
            ),
            "__data_quality_format_count_distribution": ("pricing_wide",),
        }
        for relation, upstreams in expected_upstreams.items():
            self.assertEqual(generator.RELATION_METADATA[relation].upstream, upstreams)
        metric = self.field_metadata[("__data_quality_metrics", "metric_value")]
        self.assertIn("(category, check_id, metric_name)", metric.source)
        self.assertIn("may be negative", metric.source)
        self.assertNotIn("scope varies", metric.source)
        self.assertIn(
            "ROUND(100.0 * rows_matched / pricing_rows, 2)",
            self.field_metadata[("__data_quality_pricing_match_by_period", "match_pct")].source,
        )
        self.assertIn(
            "ROUND(100.0 * unmatched / pricing_sections, 1)",
            self.field_metadata[("__data_quality_top_unmatched_pricing_sections", "unmatched_pct")].source,
        )
        self.assertIn(
            "section-only",
            self.field_metadata[("__data_quality_top_unmatched_pricing_sections", "pricing_sections")].source,
        )

    def test_semantic_contracts_are_anchored_in_executable_sql(self) -> None:
        pricing_import = (REPO_ROOT / "scripts/sql/1_bookprices_import.sql").read_text(
            encoding="utf-8"
        )
        pricing_wide = (REPO_ROOT / "scripts/sql/2c_pricing_wide.sql").read_text(
            encoding="utf-8"
        )
        merged = (REPO_ROOT / "scripts/sql/4_merged_records.sql").read_text(
            encoding="utf-8"
        )
        dq_sql = (REPO_ROOT / "scripts/sql/2d_data_quality.sql").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "STRING_AGG(DISTINCT instructor_name, ', ' ORDER BY instructor_name)",
            pricing_import,
        )
        self.assertIn(
            "COUNT(DISTINCT (book_option, book_condition, book_format))",
            pricing_wide,
        )
        self.assertIn(
            "(base.required_cost_owned_min + base.required_cost_owned_max) / 2.0",
            merged,
        )
        self.assertRegex(
            dq_sql,
            r"CREATE TABLE __data_quality_top_unmatched_ipeds_schools AS\s+"
            r"SELECT school, unit_id, COUNT\(\*\) AS catalog_rows\s+"
            r"FROM comprehensive_data",
        )
        self.assertIn(
            "FROM comprehensive_data\nWHERE is_required_inferred = TRUE AND ISBN13 IS NULL",
            dq_sql,
        )
        self.assertIn("ROUND(100.0 * SUM(CASE", dq_sql)
        self.assertIn("/ COUNT(*), 2) AS match_pct", dq_sql)
        self.assertIn("/ COUNT(*), 1) AS unmatched_pct", dq_sql)

    def test_checked_in_output_is_reproducible_and_check_is_clean(self) -> None:
        rendered = generator.generate_documents(SCHEMA, APPENDIX, OUTPUT, DOCS_DIRECTORY)
        self.assertEqual(rendered.index, self.index)
        self.assertEqual(rendered.relation_docs, self.docs)
        self.assertEqual(generator.check_documents(rendered, OUTPUT, DOCS_DIRECTORY), [])
        result = subprocess.run(
            ["python3", str(GENERATOR_PATH), "--check"],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_stale_relation_document_requires_explicit_prune(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            output = root / "DATA-DICTIONARY.md"
            docs = root / "docs/data-dictionary"
            rendered = generator.generate_documents(SCHEMA, APPENDIX, output, docs)
            generator.write_documents(rendered, output, docs)
            stale = docs / "removed_relation.md"
            stale.write_text(generator.GENERATED_MARKER + "\n", encoding="utf-8")
            rerendered = generator.generate_documents(SCHEMA, APPENDIX, output, docs)
            self.assertEqual(generator.check_documents(rerendered, output, docs), [stale])
            with self.assertRaisesRegex(ValueError, "rerun with --prune"):
                generator.write_documents(rerendered, output, docs)
            self.assertTrue(stale.exists())
            result = subprocess.run(
                [
                    "python3", str(GENERATOR_PATH),
                    "--schema", str(SCHEMA),
                    "--appendix", str(APPENDIX),
                    "--output", str(output),
                    "--docs-directory", str(docs),
                    "--prune",
                ],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(stale.exists())

    def test_validated_frontmatter_is_preserved_without_generating_new_ids(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            output = root / "DATA-DICTIONARY.md"
            docs = root / "docs/data-dictionary"
            rendered = generator.generate_documents(SCHEMA, APPENDIX, output, docs)
            generator.write_documents(rendered, output, docs)
            page = docs / "course_catalog_20251215.md"
            original = page.read_text(encoding="utf-8")
            frontmatter = (
                "---\n"
                "notion-id: 11111111-1111-1111-1111-111111111111\n"
                "notion-url: https://notion.example/page\n"
                "notion-sync: push\n"
                "---\n\n"
            )
            page.write_text(frontmatter + original, encoding="utf-8")
            rerendered = generator.generate_documents(SCHEMA, APPENDIX, output, docs)
            self.assertTrue(
                rerendered.relation_docs["course_catalog_20251215"].startswith(
                    frontmatter + generator.GENERATED_MARKER
                )
            )
            untouched = docs / "ipeds_data.md"
            self.assertFalse(untouched.read_text(encoding="utf-8").startswith("---"))

    def test_notion_cells_do_not_contain_pipe_separators(self) -> None:
        # Notion splits even escaped pipes into extra table cells.
        for relation, body in self.docs.items():
            with self.subTest(relation=relation):
                self.assertNotIn(r"\|", body)

    def test_unrecognized_stale_markdown_is_not_deleted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            output = root / "DATA-DICTIONARY.md"
            docs = root / "docs/data-dictionary"
            rendered = generator.generate_documents(SCHEMA, APPENDIX, output, docs)
            generator.write_documents(rendered, output, docs)
            unowned = docs / "notes.md"
            unowned.write_text("# Personal notes\n", encoding="utf-8")
            rerendered = generator.generate_documents(SCHEMA, APPENDIX, output, docs)
            with self.assertRaisesRegex(ValueError, "refusing to delete"):
                generator.write_documents(rerendered, output, docs, prune=True)
            self.assertTrue(unowned.exists())

    def test_unknown_dbml_syntax_fails_loudly(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "unknown.dbml"
            path.write_text("Table known {\n  id integer\n  mystery syntax here\n}\n")
            with self.assertRaisesRegex(ValueError, "unsupported table-body syntax"):
                generator.parse_dbml(path)

    def test_unregistered_new_field_fails_resolution(self) -> None:
        relations = generator.parse_dbml(SCHEMA)
        target = next(r for r in relations if r.name == "master_isbn")
        target.columns.append(generator.Column("unexpected_new_measure", "bigint"))
        with self.assertRaisesRegex(
            ValueError, "unregistered DBML field: master_isbn.unexpected_new_measure"
        ):
            generator.resolve_field_metadata(relations, self.appendix_body)


if __name__ == "__main__":
    unittest.main()
