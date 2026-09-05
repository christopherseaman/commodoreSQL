#!/usr/bin/env python3
"""Static contract checks for retired reporting relations."""

from pathlib import Path
import re
import sys


REPO_ROOT = Path(__file__).resolve().parent.parent
CLEANUP_SQL = REPO_ROOT / "scripts/sql/0_cleanup.sql"

LEGACY_VIEWS = {
    "catalog_filtered",
    "course_records",
    "course_section_records",
    "faculty_records",
    "master_course_material",
    "summary_book_status",
    "summary_control",
    "summary_course_level",
    "summary_course_subject",
    "summary_format",
    "summary_formattype",
    "summary_ia",
    "summary_level",
    "summary_oer",
    "summary_period",
    "summary_publisher",
    "summary_sector",
    "summary_state",
    "crosstab_formattype_period",
    "crosstab_formattype_status",
    "crosstab_ia_period",
    "crosstab_ia_sector",
    "crosstab_ia_state",
    "crosstab_ia_status",
    "crosstab_oer_period",
    "crosstab_oer_sector",
    "crosstab_oer_state",
    "crosstab_oer_status",
    "crosstab_state_period",
    "crosstab_state_sector",
    "crosstab_status_period",
    "crosstab_subject_period",
    "crosstab_top_formats_period",
    "crosstab_formattype_oeria_period",
    "crosstab_formattype_oeria_status",
    "crosstab_formattype_oeria_sector",
    "crosstab_formattype_oeria_state",
}
LEGACY_TABLES = {
    "data_quality_unmatched_formats",
    "email_issues",
    "section_book_status",
    "section_cost",
    "sample10_section_ids",
}
REPLACEABLE_CURRENT_VIEWS = {
    "current_mailing_ca",
    "current_mailing_tx",
    "current_mailing_fl",
    "current_mailing_ny",
    "current_mailing_pa",
    "current_mailing_can",
    "current_mailing_other",
}
CLEANUP_VIEWS = LEGACY_VIEWS | REPLACEABLE_CURRENT_VIEWS
CLEANUP_RELATIONS = CLEANUP_VIEWS | LEGACY_TABLES
LEGACY_REPORT_RELATIONS = LEGACY_VIEWS | LEGACY_TABLES


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    cleanup = CLEANUP_SQL.read_text()
    drops = re.findall(r"^DROP (VIEW|TABLE) IF EXISTS ([a-z0-9_]+);$", cleanup, re.MULTILINE)
    dropped_views = {name for relation_type, name in drops if relation_type == "VIEW"}
    dropped_tables = {name for relation_type, name in drops if relation_type == "TABLE"}

    if dropped_views != CLEANUP_VIEWS:
        fail(f"cleanup view target set differs: {dropped_views ^ CLEANUP_VIEWS}")
    if dropped_tables != LEGACY_TABLES:
        fail(f"cleanup table target set differs: {dropped_tables ^ LEGACY_TABLES}")
    if len(drops) != 49:
        fail(f"cleanup has {len(drops)} drops, expected 49")
    if not re.search(r"^BEGIN TRANSACTION;$", cleanup, re.MULTILINE):
        fail("cleanup does not start a transaction")
    if not re.search(r"^COMMIT;$", cleanup, re.MULTILINE):
        fail("cleanup does not commit its transaction")
    if "information_schema.tables" not in cleanup or "cleanup_postcondition" not in cleanup:
        fail("cleanup lacks a catalog postcondition")
    if "WHERE table_schema = 'main'" not in cleanup:
        fail("cleanup postcondition is not scoped to the main schema")
    postcondition_sql = cleanup.split("AND table_name IN (", maxsplit=1)
    if len(postcondition_sql) != 2:
        fail("cleanup postcondition does not enumerate relation names")
    postcondition_targets = set(re.findall(r"'([a-z0-9_]+)'", postcondition_sql[1]))
    if postcondition_targets != CLEANUP_RELATIONS:
        fail("cleanup postcondition target set differs")

    runner = (REPO_ROOT / "scripts/run_sql.sh").read_text()
    import_entries = re.search(r"IMPORT_SQL=\((.*?)\n\)", runner, re.DOTALL)
    import_files = [] if import_entries is None else [
        line.strip() for line in import_entries.group(1).splitlines() if line.strip()
    ]
    expected_import_files = [
        '"0_cleanup.sql"',
        '"0_setup.sql"',
        '"0b_state_region.sql"',
        '"1_bookprices_import.sql"',
        '"1a_supply_classification.sql"',
        '"1b_section_enrollment.sql"',
        '"2_oer_classification.sql"',
        '"2b_course_materials.sql"',
        '"2c_pricing_wide.sql"',
        '"2d_data_quality.sql"',
    ]
    if import_files != expected_import_files:
        fail("IMPORT step list or order differs from the cleanup contract")

    parquet_exporter = (REPO_ROOT / "scripts/export_all_parquet.sh").read_text()
    if "find sql/exports -maxdepth 1 -type f -name \"*.sql\"" not in parquet_exporter:
        fail("Parquet exporter does not limit discovery to top-level exports")

    retired_producers = [
        REPO_ROOT / "scripts/sql/5_univariate_summaries.sql",
        REPO_ROOT / "scripts/sql/6_crosstab_summaries.sql",
    ]
    for path in retired_producers:
        if path.exists():
            fail(f"retired producer remains: {path.relative_to(REPO_ROOT)}")
    optional_exports = list((REPO_ROOT / "scripts/sql/exports/optional").glob("*.sql"))
    if optional_exports:
        fail("retired optional wrapper(s) remain")

    report_paths = list((REPO_ROOT / "scripts/sql/exports").rglob("*.sql"))
    report_paths.extend((REPO_ROOT / "metabase").rglob("*.sql"))
    references = []
    pattern = re.compile(r"\b(" + "|".join(sorted(LEGACY_REPORT_RELATIONS)) + r")\b")
    for path in report_paths:
        if match := pattern.search(path.read_text()):
            references.append(f"{path.relative_to(REPO_ROOT)}: {match.group(1)}")
    if references:
        fail("legacy report reference(s): " + ", ".join(references))

    canonical_docs = [
        REPO_ROOT / "SCHEMA.md",
        REPO_ROOT / "CMM-ETL.md",
        REPO_ROOT / "DATA-DICTIONARY.md",
        REPO_ROOT / "MAILING-FLOW.md",
    ]
    retired_geography_pattern = re.compile(
        r"\b(" + "|".join(sorted(REPLACEABLE_CURRENT_VIEWS)) + r")\b"
    )
    for path in canonical_docs:
        if match := retired_geography_pattern.search(path.read_text()):
            fail(f"retired mailing relation in {path.name}: {match.group(1)}")

    schema_doc = (REPO_ROOT / "SCHEMA.md").read_text()
    required_execution_markers = (
        "| IMPORT | 10 fixed SQL files |",
        'i0c["01 · 0_cleanup.sql"]',
        'i2d["10 · 2d_data_quality.sql"]',
        'e30["11 · 3_mailing_lists.sql"]',
        'm03["16 · models/sample10pct_materials.sql"]',
    )
    if any(marker not in schema_doc for marker in required_execution_markers):
        fail("SCHEMA.md does not show the exact 16-step processing order")
    if "| Import | `0_cleanup.sql` |" not in (REPO_ROOT / "CMM-ETL.md").read_text():
        fail("CMM-ETL.md omits the cleanup step")

    print("PASS: 49 exact cleanup relations are targeted with no legacy report references.")


if __name__ == "__main__":
    main()
