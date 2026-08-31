#!/usr/bin/env python3
"""Tests for the deterministic project-wide data dictionary generator."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
import importlib.util
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA = REPO_ROOT / "schema.dbml"
APPENDIX = REPO_ROOT / "MASTER-SECTION-DICTIONARY.md"
OUTPUT = REPO_ROOT / "DATA-DICTIONARY.md"
GENERATOR_PATH = REPO_ROOT / "scripts/generate_data_dictionary.py"
SPEC = importlib.util.spec_from_file_location("generate_data_dictionary", GENERATOR_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"could not import {GENERATOR_PATH}")
generator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = generator
SPEC.loader.exec_module(generator)


class DataDictionaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.relations = generator.parse_dbml(SCHEMA)
        cls.rendered = OUTPUT.read_text(encoding="utf-8")
        cls.appendix_body = APPENDIX.read_text(encoding="utf-8")
        cls.field_metadata = generator.resolve_field_metadata(
            cls.relations, cls.appendix_body
        )
        cls.generated_body = cls.rendered.split(
            "\n## Detailed Master Section appendix\n", 1
        )[0]

    def test_every_relation_has_one_index_row_and_one_schema_section(self) -> None:
        for relation in self.relations:
            with self.subTest(relation=relation.name):
                index_prefix = f"| `{relation.name}` | {relation.kind} |"
                self.assertEqual(self.generated_body.count(index_prefix), 1)
                self.assertEqual(
                    self.generated_body.count(f"### `{relation.name}`\n"), 1
                )

    def test_every_declared_column_appears_once_in_its_relation(self) -> None:
        relation_body = self.generated_body.split("\n## Relation columns\n", 1)[1]
        for relation in self.relations:
            marker = f"### `{relation.name}`\n"
            section = relation_body.split(marker, 1)[1].split("\n### `", 1)[0]
            self.assertEqual(
                section.count(
                    "| Column name | Data type | Source / derivation | Values / format | Population / denominator | NULL meaning |"
                ),
                1,
            )
            for column in relation.columns:
                with self.subTest(relation=relation.name, column=column.name):
                    row_prefix = f"| `{column.name}` | `{column.data_type}` |"
                    self.assertEqual(section.count(row_prefix), 1)

    def test_select_star_view_schemas_match_their_bases(self) -> None:
        relations = {relation.name: relation for relation in self.relations}
        for view_name, base_name in generator.INHERITED_VIEW_BASES.items():
            with self.subTest(view=view_name, base=base_name):
                view = relations[view_name]
                base = relations[base_name]
                self.assertEqual(view.kind, "view")
                self.assertEqual(
                    [(column.name, column.data_type) for column in view.columns],
                    [(column.name, column.data_type) for column in base.columns],
                )
                context = generator.VIEW_FILTER_CONTEXT[view_name]
                for column in view.columns:
                    inherited = self.field_metadata[(view_name, column.name)]
                    base_metadata = self.field_metadata[(base_name, column.name)]
                    self.assertEqual(inherited.metadata_kind, "inherited")
                    self.assertEqual(inherited.values, base_metadata.values)
                    self.assertEqual(inherited.null_meaning, base_metadata.null_meaning)
                    self.assertIn(f"`{base_name}.{column.name}`", inherited.source)
                    self.assertIn(context, inherited.population)

    def test_every_mailing_sql_view_is_declared(self) -> None:
        sql = (REPO_ROOT / "scripts/sql/3_mailing_lists.sql").read_text(
            encoding="utf-8"
        )
        created_views = set(
            re.findall(
                r"^CREATE VIEW\s+([A-Za-z_][A-Za-z0-9_]*)\s+AS$",
                sql,
                flags=re.MULTILINE,
            )
        )
        declared_views = {
            relation.name for relation in self.relations if relation.kind == "view"
        }
        self.assertTrue(created_views)
        self.assertEqual(created_views - declared_views, set())
        self.assertIn("recent_periods", created_views)

    def test_mailing_relations_and_lineage_match_canonical_architecture(self) -> None:
        relations = {relation.name: relation for relation in self.relations}
        self.assertEqual(relations["master_mailing"].kind, "table")
        self.assertEqual(relations["current_mailing"].kind, "view")
        self.assertEqual(relations["recent_periods"].kind, "view")
        for cache_name in ("master_mailing_cache", "current_mailing_cache"):
            self.assertNotIn(cache_name, relations)
            self.assertNotIn(cache_name, generator.RELATION_METADATA)
            self.assertNotIn(f"### `{cache_name}`", self.generated_body)

        self.assertEqual(
            generator.RELATION_METADATA["master_mailing"].upstream,
            ("course_catalog_20251215",),
        )
        self.assertEqual(
            generator.RELATION_METADATA["recent_periods"].upstream,
            ("master_mailing",),
        )
        self.assertEqual(
            generator.RELATION_METADATA["current_mailing"].upstream,
            ("master_mailing", "recent_periods", "panel_email", "opt_out"),
        )

        master = self.field_metadata[("master_mailing", "email")]
        current = self.field_metadata[("current_mailing", "email")]
        panel = self.field_metadata[("current_mailing", "panel_response_year")]
        recent = self.field_metadata[("recent_periods", "period_sortable")]
        self.assertIn("`course_catalog_20251215.email`", master.source)
        self.assertIn("`${SURVEY_TABLE}`", master.source)
        self.assertIn("opt_out and panel history do not participate", master.population)
        self.assertIn("`master_mailing.email`", current.source)
        self.assertIn("`recent_periods`", current.source)
        self.assertIn("`NOT EXISTS`", current.source)
        self.assertIn("`opt_out.email`", current.source)
        self.assertIn("`panel_email.panel_response_year` LEFT JOINed", panel.source)
        self.assertIn("`master_mailing.period_sortable`", recent.source)

    def test_mailing_sql_uses_source_selection_and_working_view(self) -> None:
        sql = (REPO_ROOT / "scripts/sql/3_mailing_lists.sql").read_text(
            encoding="utf-8"
        )
        self.assertIn("CREATE TABLE master_mailing AS", sql)
        self.assertIn("FROM ${SURVEY_TABLE}", sql)
        self.assertNotIn("FROM comprehensive_data", sql)
        self.assertIn("FROM master_mailing\nWHERE period_sortable IS NOT NULL", sql)
        self.assertIn("CREATE VIEW current_mailing AS", sql)
        self.assertIn("LEFT JOIN panel_email", sql)
        self.assertIn("NOT EXISTS", sql)
        self.assertNotRegex(sql, r"CREATE (?:TABLE|VIEW) (?:master|current)_mailing_cache")

        runner = (REPO_ROOT / "scripts/run_sql.sh").read_text(encoding="utf-8")
        self.assertIn("information_schema.tables", runner)
        self.assertIn('table_name = \'master_mailing\'', runner)
        self.assertIn('${DUCKDB} "${MAIN_DB}" -c "DROP VIEW master_mailing;"', runner)

    def test_registry_exactly_covers_canonical_relations(self) -> None:
        self.assertEqual(
            {relation.name for relation in self.relations},
            set(generator.RELATION_METADATA),
        )

    def test_frontmatter_owns_the_notion_destination(self) -> None:
        expected = (
            "---\n"
            f"notion-id: {generator.NOTION_ID}\n"
            f"notion-url: {generator.NOTION_URL}\n"
            "notion-sync: push\n"
            "---\n\n"
            "# CommodoreSQL data dictionary\n"
        )
        self.assertTrue(self.rendered.startswith(expected))
        self.assertEqual(self.rendered.count("\n# CommodoreSQL data dictionary\n"), 1)
        self.assertNotIn("\n# Master Section release dictionary\n", self.rendered)
        owners = []
        for path in REPO_ROOT.rglob("*.md"):
            text = path.read_text(encoding="utf-8")
            if f"notion-id: {generator.NOTION_ID}" in text:
                owners.append(path.relative_to(REPO_ROOT).as_posix())
        self.assertEqual(owners, ["DATA-DICTIONARY.md"])
        self.assertFalse(APPENDIX.read_text(encoding="utf-8").startswith("---"))

    def test_checked_in_output_is_reproducible(self) -> None:
        self.assertEqual(generator.generate(SCHEMA, APPENDIX), self.rendered)
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/generate_data_dictionary.py"), "--check"],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unknown_dbml_syntax_fails_loudly(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "unknown.dbml"
            path.write_text("Table known {\n  id integer\n  mystery syntax here\n}\n")
            with self.assertRaisesRegex(ValueError, "unsupported table-body syntax"):
                generator.parse_dbml(path)

    def test_dbml_field_notes_precede_structural_formats(self) -> None:
        noted = generator.Column("period", "varchar", 'e.g. "Fall 2024"')
        fallback_boolean = generator.Column("flag", "boolean")
        self.assertEqual(generator.field_values(noted), 'e.g. "Fall 2024"')
        self.assertEqual(
            generator.field_values(fallback_boolean), "TRUE or FALSE"
        )

    def test_parsed_isbn_fields_retain_notes_and_identifier_format(self) -> None:
        expected_relations = (
            "course_materials",
            "course_materials_post_2024",
            "course_materials_use",
            "course_materials_no_use",
            "course_materials_canada",
            "material_costs",
            "supply_isbn_classification",
            "master_isbn",
        )
        for relation_name in expected_relations:
            with self.subTest(relation=relation_name):
                column = next(
                    column
                    for relation in self.relations
                    if relation.name == relation_name
                    for column in relation.columns
                    if column.name == "isbn13"
                )
                values = self.field_metadata[(relation_name, "isbn13")].values
                self.assertIn("ISBN", values)
                self.assertRegex(values, r"source identifier|pseudo-SKU")

    def test_parsed_pricing_boolean_null_semantics_match_sql(self) -> None:
        expected = {
            ("pricing_historical", "required"): "NULL when Book Status is missing",
            ("pricing_wide", "required"): "NULL when every retained row has required = NULL",
            ("pricing_wide", "has_buy"): "NULL when every retained row has book_option = NULL",
            ("pricing_wide", "has_rent"): "NULL when every retained row has book_option = NULL",
        }
        for key, phrase in expected.items():
            with self.subTest(field=".".join(key)):
                relation = next(relation for relation in self.relations if relation.name == key[0])
                self.assertIn(key[1], {column.name for column in relation.columns})
                self.assertIn(phrase, self.field_metadata[key].null_meaning)
                self.assertNotIn("Never NULL", self.field_metadata[key].null_meaning)

    def test_master_course_material_declares_full_sql_group_grain_and_filters(self) -> None:
        relation = next(r for r in self.relations if r.name == "master_course_material")
        group_keys = (
            "course_id", "period_sortable", "period", "period_date", "school",
            "department", "course_number", "course_title", "publisher", "book_status",
        )
        self.assertTrue(set(group_keys).issubset({column.name for column in relation.columns}))
        sql = (REPO_ROOT / "scripts/sql/4_merged_records.sql").read_text(encoding="utf-8")
        group_by = sql.split("CREATE VIEW master_course_material AS", 1)[1].split(";", 1)[0]
        group_clause = group_by.split("GROUP BY", 1)[1]
        actual_group_keys = tuple(re.findall(r"\b[a-z][a-z0-9_]*\b", group_clause))
        self.assertEqual(set(actual_group_keys), set(group_keys))
        self.assertEqual(len(actual_group_keys), len(group_keys))
        where_clause = group_by.split("WHERE", 1)[1].split("GROUP BY", 1)[0]
        self.assertEqual(
            set(re.findall(r"\b([a-z][a-z0-9_]*)\s+IS\s+NOT\s+NULL\b", where_clause)),
            {"course_id", "publisher", "period_sortable"},
        )
        self.assertEqual(
            generator.RELATION_METADATA["master_course_material"].grain,
            "One (course_id, period_sortable, period, period_date, school, department, course_number, course_title, publisher, book_status) group",
        )
        for key in ("course_id", "publisher", "period_sortable"):
            metadata = self.field_metadata[("master_course_material", key)]
            self.assertIn(f"`{key} IS NOT NULL`", metadata.source)
            self.assertIn(f"`{key}` is NULL", metadata.null_meaning)
        for key in set(group_keys) - {"course_id", "publisher", "period_sortable"}:
            metadata = self.field_metadata[("master_course_material", key)]
            self.assertIn("SQL groups missing source values together", metadata.source)
            self.assertIn("May be NULL", metadata.null_meaning)

    def test_field_contract_resolves_exactly_all_canonical_fields(self) -> None:
        expected = {
            (relation.name, column.name)
            for relation in self.relations
            for column in relation.columns
        }
        self.assertEqual(set(self.field_metadata), expected)
        self.assertEqual(
            len(self.field_metadata),
            sum(len(relation.columns) for relation in self.relations),
        )
        self.assertEqual(
            {item.metadata_kind for item in self.field_metadata.values()},
            {"inherited", "aggregate", "passthrough", "source", "appendix", "joined", "dq", "derived", "explicit"},
        )

    def test_mandatory_semantic_fields_are_nonempty(self) -> None:
        for key, item in self.field_metadata.items():
            with self.subTest(field=".".join(key)):
                self.assertTrue(item.source.strip())
                self.assertTrue(item.values.strip())
                self.assertTrue(item.population.strip())
                self.assertTrue(item.null_meaning.strip())
                self.assertTrue(item.metadata_kind.strip())

    def test_no_generic_placeholders_are_rendered(self) -> None:
        banned = {
            "String or NULL",
            "Integer or NULL",
            "Identifier or NULL",
            "Numeric value or NULL",
            "Relation upstream (not field-specific)",
        }
        for phrase in banned:
            self.assertNotIn(phrase, self.rendered)
        for key, item in self.field_metadata.items():
            if item.metadata_kind in {"derived", "aggregate", "dq"}:
                combined = " ".join(
                    (item.source, item.values, item.population, item.null_meaning)
                )
                with self.subTest(field=".".join(key)):
                    self.assertTrue(banned.isdisjoint(combined))

    def test_source_fields_name_external_fields_and_normalization(self) -> None:
        examples = {
            ("course_catalog_20251215", "email"): ("`E-Mail`", "lowercase + trim"),
            ("course_catalog_20251215", "enrollments"): ("`Enrollments`", "TRY_CAST"),
            ("ipeds_data", "unitid"): ("`UNITID`", "TRY_CAST"),
            ("opt_out", "email"): ("`Email`", "lowercase + trim"),
            ("panel", "email"): ("`Unique`", "lowercase + trim"),
            ("pricing_historical", "price"): ("`Price`", "TRY_CAST"),
        }
        for key, snippets in examples.items():
            with self.subTest(field=".".join(key)):
                source = self.field_metadata[key].source
                for snippet in snippets:
                    self.assertIn(snippet, source)

    def test_structural_passthrough_names_the_base_column(self) -> None:
        examples = {
            ("comprehensive_data", "course_id"): "course_catalog_20251215.course_id",
            ("material_costs", "book_title"): "course_materials_use.book_title",
            ("material_costs", "price_buy_new_physical"): "pricing_wide.price_buy_new_physical",
            ("current_mailing", "email"): "master_mailing.email",
        }
        for key, reference in examples.items():
            with self.subTest(field=".".join(key)):
                self.assertIn(f"`{reference}`", self.field_metadata[key].source)

    def test_master_section_appendix_exactly_owns_its_field_contract(self) -> None:
        parsed = generator.parse_master_section_metadata(self.appendix_body)
        master = next(r for r in self.relations if r.name == "master_section")
        self.assertEqual(set(parsed), {column.name for column in master.columns})
        self.assertEqual(len(parsed), 66)
        for column in master.columns:
            source, population, null_meaning = parsed[column.name]
            item = self.field_metadata[("master_section", column.name)]
            self.assertEqual(item.metadata_kind, "appendix")
            self.assertEqual(
                (item.source, item.population, item.null_meaning),
                (source, population, null_meaning),
            )

    def test_master_release_count_denominators_are_exact(self) -> None:
        institution = self.field_metadata
        self.assertIn(
            "supply-aware raw `section_book_status.has_required`",
            institution[("master_institution", "required_section_count")].source,
        )
        self.assertIn(
            "`enrollment_assigned IS NOT NULL`",
            institution[("master_institution", "enrollment_section_count")].source,
        )
        self.assertIn(
            "sentinel 9999 is excluded",
            institution[("master_institution", "seats_taken_tot")].null_meaning,
        )
        self.assertIn(
            "COUNT(DISTINCT section_id)",
            institution[("master_isbn", "price_buy_new_physical_count")].source,
        )
        self.assertIn(
            "Distinct ISBN-using sections",
            institution[("master_isbn", "price_buy_new_physical_count")].population,
        )
        self.assertIn(
            "Constant FALSE",
            institution[("master_isbn", "is_supply")].source,
        )

    def test_root_audit_metadata_corrections_are_exact(self) -> None:
        context = generator.VIEW_FILTER_CONTEXT["master_section_us_intro_fall2025"]
        for snippet in (
            "`period_sortable = '2025-4'`",
            "`required_count >= 1`",
            "`Introductory or general undergraduate`",
            "`Intermediate undergraduate`",
            "non-NULL `state NOT IN ('CAN', '')`",
        ):
            self.assertIn(snippet, context)

        for data_type in ("varchar", "bigint"):
            isbn_format = generator.field_values(
                generator.Column("isbn13", data_type)
            )
            self.assertIn("source identifier/pseudo-SKU", isbn_format)
        self.assertEqual(
            self.field_metadata[("course_materials", "source_row_count")].null_meaning,
            "Never NULL or zero for a retained group.",
        )
        for field in ("use_source_row_count", "no_use_source_row_count"):
            self.assertIn(
                "zero is possible for the filtered count",
                self.field_metadata[("course_materials", field)].null_meaning,
            )
        for field in ("school", "department", "course_number", "course_title"):
            metadata = self.field_metadata[("master_course_material", field)]
            self.assertIn("Group key", metadata.source)
            self.assertNotIn("Representative", metadata.source)

    def test_mailing_sql_behavior_on_tiny_duckdb_fixture(self) -> None:
        mailing_sql = (REPO_ROOT / "scripts/sql/3_mailing_lists.sql").read_text(
            encoding="utf-8"
        ).replace("${CONFIG}", "").replace("${SURVEY_TABLE}", "survey_fixture")
        periods = ["2022-4"] + [
            f"{year}-{term}" for year in range(2023, 2026) for term in range(1, 5)
        ]
        rows = []
        for index, period in enumerate(periods):
            state = "PA" if period == "2025-3" else "CAN" if period == "2025-2" else None if period == "2025-1" else "CA"
            state_sql = "NULL" if state is None else f"'{state}'"
            rows.append(
                f"({1000 + index}, 'Period {period}', {state_sql}, 'Dept', 'Introductory or general undergraduate', "
                f"'Subject', 'Term {period}', '{period}', DATE '2025-01-01', 'Instructor', 'First', 'Last', "
                f"'period-{period}@example.com', {index}, 'course-{index}', 'section-{index}')"
            )
        rows.extend(
            [
                "(2000, 'Old Active', 'TX', 'Dept', 'Level', 'Subject', 'Old', '2024-4', DATE '2024-10-01', 'Old', 'A', 'User', 'active@example.com', 999, 'course-old', 'section-old')",
                "(2001, 'New Low', 'CA', 'Dept', 'Level', 'Subject', 'New', '2025-4', DATE '2025-10-01', 'New', 'A', 'User', 'active@example.com', 5, 'course-new-a', 'section-new-a')",
                "(2002, 'New High', 'CA', 'Dept', 'Level', 'Subject', 'New', '2025-4', DATE '2025-10-01', 'New', 'A', 'User', 'active@example.com', 10, 'course-new-b', 'section-new-b')",
                "(3000, 'Blocked', 'NY', 'Dept', 'Level', 'Subject', 'New', '2025-4', DATE '2025-10-01', 'Blocked', 'B', 'User', 'blocked@example.com', 10, 'course-blocked', 'section-blocked')",
                "(4000, 'Blank', 'CA', 'Dept', 'Level', 'Subject', 'New', '2025-4', DATE '2025-10-01', 'Blank', 'B', 'User', '   ', 1, 'course-blank', 'section-blank')",
            ]
        )
        fixture_sql = """
            CREATE TABLE survey_fixture (
                unit_id BIGINT, school VARCHAR, state VARCHAR, department VARCHAR,
                course_level VARCHAR, course_subject VARCHAR, period VARCHAR,
                period_sortable VARCHAR, period_date DATE, instructor VARCHAR,
                first_name VARCHAR, last_name VARCHAR, email VARCHAR,
                enrollments INTEGER, course_id VARCHAR, section_id VARCHAR
            );
            INSERT INTO survey_fixture VALUES
        """ + ",\n".join(rows) + ";\n" + """
            CREATE TABLE panel_email (email VARCHAR, panel_response_year VARCHAR);
            INSERT INTO panel_email VALUES ('active@example.com', '2024');
            CREATE TABLE opt_out (email VARCHAR);
            INSERT INTO opt_out VALUES ('blocked@example.com'), ('blocked@example.com');
        """

        with tempfile.TemporaryDirectory() as temporary_directory:
            database = Path(temporary_directory) / "mailing.duckdb"
            for invocation, script in enumerate((fixture_sql + mailing_sql, mailing_sql), 1):
                result = subprocess.run(
                    ["duckdb", str(database)],
                    input=script,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, f"run {invocation}: {result.stderr}")

            query = """
                SELECT
                    (SELECT table_type FROM information_schema.tables WHERE table_name='master_mailing'),
                    (SELECT table_type FROM information_schema.tables WHERE table_name='current_mailing'),
                    (SELECT school FROM master_mailing WHERE email='active@example.com'),
                    (SELECT COUNT(*) FROM master_mailing WHERE email='blocked@example.com'),
                    (SELECT COUNT(*) FROM current_mailing WHERE email='blocked@example.com'),
                    (SELECT panel_response_year FROM current_mailing WHERE email='active@example.com'),
                    (SELECT COUNT(*) FROM recent_periods),
                    (SELECT MIN(period_sortable) FROM recent_periods),
                    (SELECT COUNT(*) FROM current_mailing WHERE email='period-2022-4@example.com'),
                    (SELECT COUNT(*) FROM current_mailing),
                    (SELECT COUNT(*) FROM (
                        SELECT email FROM current_mailing_ca
                        UNION ALL SELECT email FROM current_mailing_tx
                        UNION ALL SELECT email FROM current_mailing_fl
                        UNION ALL SELECT email FROM current_mailing_ny
                        UNION ALL SELECT email FROM current_mailing_pa
                        UNION ALL SELECT email FROM current_mailing_can
                        UNION ALL SELECT email FROM current_mailing_other
                    )),
                    (SELECT COUNT(*) FROM current_mailing_pa),
                    (SELECT COUNT(*) FROM current_mailing_can),
                    (SELECT COUNT(*) FROM current_mailing_other);
            """
            result = subprocess.run(
                ["duckdb", str(database), "-csv", "-noheader", "-c", query],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                result.stdout.strip(),
                "BASE TABLE,VIEW,New High,1,0,2024,12,2023-1,0,13,13,1,1,1",
            )

    def test_dq_metadata_preserves_executable_scope(self) -> None:
        self.assertIn(
            "Required-inferred catalog rows",
            self.field_metadata[
                ("__data_quality_top_null_isbn_schools", "null_isbn_rows")
            ].population,
        )
        self.assertIn(
            "All final `pricing_historical` rows",
            self.field_metadata[
                ("__data_quality_pricing_match_by_period", "rows_matched")
            ].population,
        )
        self.assertIn(
            "scope varies by category/check_id",
            self.field_metadata[("__data_quality_metrics", "metric_value")].source,
        )

    def test_unregistered_new_dbml_column_fails_resolution(self) -> None:
        relations = generator.parse_dbml(SCHEMA)
        target = next(r for r in relations if r.name == "master_isbn")
        target.columns.append(generator.Column("unexpected_new_measure", "bigint"))
        with self.assertRaisesRegex(
            ValueError, "unregistered DBML field: master_isbn.unexpected_new_measure"
        ):
            generator.resolve_field_metadata(relations, self.appendix_body)

    def test_master_section_appendix_drift_fails_resolution(self) -> None:
        appendix = self.appendix_body.replace(
            "| `section_id` | Section-offering ID |",
            "| `removed_section_id` | Section-offering ID |",
            1,
        )
        with self.assertRaisesRegex(ValueError, "appendix coverage mismatch"):
            generator.resolve_field_metadata(self.relations, appendix)


if __name__ == "__main__":
    unittest.main()
