#!/usr/bin/env python3
"""Generate the project-wide data dictionary from the canonical DBML schema."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


NOTION_ID = "3cbd9fdd-1a1a-8082-b697-ca7f5ef1d6ed"
NOTION_URL = (
    "https://app.notion.com/p/sqrlly/"
    "Data-Dictionary-3cbd9fdd1a1a8082b697ca7f5ef1d6ed"
)


@dataclass(frozen=True)
class Column:
    name: str
    data_type: str
    note: str | None = None


@dataclass
class Relation:
    name: str
    kind: str
    columns: list[Column] = field(default_factory=list)
    note: str | None = None


@dataclass(frozen=True)
class RelationMetadata:
    stage: str
    grain: str
    upstream: tuple[str, ...]
    intended_use: str
    view_schema: str | None = None


@dataclass(frozen=True)
class FieldMetadata:
    """Resolved, renderable semantic contract for one DBML field."""

    source: str
    values: str
    population: str
    null_meaning: str
    metadata_kind: str


# This registry is deliberately explicit. schema.dbml owns relation/column shape; the
# named SQL stages and CMM-ETL.md own the conservative relation-level lineage below.
RELATION_METADATA: dict[str, RelationMetadata] = {
    "course_catalog_20251215": RelationMetadata("IMPORT / 0_setup.sql", "One normalized Discovery Extract source row", ("BMG DiscoveryExtract.20251215.csv",), "Raw normalized course-materials and adoption source in a compatibility-named table."),
    "ipeds_data": RelationMetadata("IMPORT / 0_setup.sql", "One IPEDS institution (unitid)", ("IPEDS IPEDS_2024.csv",), "Institutional characteristics lookup."),
    "opt_out": RelationMetadata("IMPORT / 0_setup.sql", "One cleaned email", ("BVA OptOut_20251215.csv",), "Mailing opt-out lookup in a compatibility-named table."),
    "panel": RelationMetadata("IMPORT / 0_setup.sql", "One retained panel source row", ("BVA panel_20260108.csv",), "Raw mailing/panel response history in a compatibility-named table."),
    "panel_email": RelationMetadata("IMPORT / 0_setup.sql", "One cleaned email", ("panel",), "Deduplicated panel enrichment that preserves multiplicity audits."),
    "format_type_classification": RelationMetadata("IMPORT / 2_oer_classification.sql", "One FormatType", ("format_type_lookup.tsv",), "OER and inclusive-access classification lookup."),
    "pricing_historical": RelationMetadata("IMPORT step 3 / 1_bookprices_import.sql", "One latest section × ISBN × option × condition × format × rental-term row", ("BMG BookPricing.Historical_20260224.csv",), "Deduplicated BMG-owned raw pricing/cost history in a compatibility-named table."),
    "supply_isbn_classification": RelationMetadata("IMPORT derived / 1a_supply_classification.sql", "One classified ISBN", ("course_catalog_20251215", "supply_keywords.tsv"), "Precision-oriented supply classification audit."),
    "section_book_status": RelationMetadata("IMPORT derived / 1b_section_filter.sql", "One period-specific section_id", ("course_catalog_20251215", "supply_isbn_classification"), "Supply-aware required-status fallback lookup."),
    "state_region": RelationMetadata("IMPORT derived / 0b_state_region.sql", "One state or province code", ("0b_state_region.sql static values",), "Census region and division lookup."),
    "pricing_wide": RelationMetadata("IMPORT derived / 2c_pricing_wide.sql", "One section_id × ISBN13", ("pricing_historical",), "BMG-owned wide price and availability pivot."),
    "comprehensive_data": RelationMetadata("IMPORT derived / 2_oer_classification.sql", "One normalized catalog source row", ("course_catalog_20251215", "format_type_classification", "ipeds_data", "section_book_status", "supply_isbn_classification", "opt_out", "panel_email"), "Authoritative enriched source-row table and canonical-material/DQ source."),
    "course_materials": RelationMetadata("Canonical materials / 2b_course_materials.sql", "One period × section × ISBN, plus one NULL-ISBN audit row per section when present", ("comprehensive_data", "section_enrollment"), "First canonical processed item spine with variant and conflict evidence."),
    "course_materials_post_2024": RelationMetadata("Canonical materials / 2b_course_materials.sql", "Filtered course_materials rows", ("course_materials",), "Post-2024 canonical material projection.", "All columns inherited from course_materials; filter: is_post_2024."),
    "course_materials_use": RelationMetadata("Canonical materials / 2b_course_materials.sql", "Filtered course_materials rows", ("course_materials",), "Canonical Use material projection.", "All columns inherited from course_materials; filter: is_course_material_use."),
    "course_materials_no_use": RelationMetadata("Canonical materials / 2b_course_materials.sql", "Filtered course_materials rows", ("course_materials",), "Canonical NoUse audit projection.", "All columns inherited from course_materials; filter: is_course_material_no_use."),
    "course_materials_canada": RelationMetadata("Canonical materials / 2b_course_materials.sql", "Filtered course_materials rows", ("course_materials",), "Canadian NoUse audit projection.", "All columns inherited from course_materials; filter: is_course_material_no_use AND is_canada."),
    "section_enrollment": RelationMetadata("Canonical sections / 2b_course_materials.sql", "One valid 2024+ period × section", ("comprehensive_data",), "Complete section population and authoritative enrollment assignment."),
    "master_mailing": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "One non-NULL, nonblank cleaned email", ("course_catalog_20251215",), "Persisted canonical deterministic mailing selection; independent of opt-out and panel history."),
    "recent_periods": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "One of the latest 12 distinct non-NULL periods", ("master_mailing",), "Period boundary used by current_mailing.", "Declared one-column projection from persisted master_mailing."),
    "current_mailing": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "One non-opted-out cleaned email selected in the latest 12 master periods", ("master_mailing", "recent_periods", "panel_email", "opt_out"), "Whiteboard Mailing Working view with panel response enrichment.", "Master fields pass through; panel_response_year is LEFT-joined; recent-period and opt-out filters define population."),
    "current_mailing_ca": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "Filtered current_mailing rows", ("current_mailing",), "California mailing projection.", "All columns inherited from current_mailing; normalized state = CA."),
    "current_mailing_tx": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "Filtered current_mailing rows", ("current_mailing",), "Texas mailing projection.", "All columns inherited from current_mailing; normalized state = TX."),
    "current_mailing_fl": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "Filtered current_mailing rows", ("current_mailing",), "Florida mailing projection.", "All columns inherited from current_mailing; normalized state = FL."),
    "current_mailing_ny": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "Filtered current_mailing rows", ("current_mailing",), "New York mailing projection.", "All columns inherited from current_mailing; normalized state = NY."),
    "current_mailing_pa": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "Filtered current_mailing rows", ("current_mailing",), "Pennsylvania mailing projection.", "All columns inherited from current_mailing; normalized state = PA."),
    "current_mailing_can": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "Filtered current_mailing rows", ("current_mailing",), "Canada mailing projection.", "All columns inherited from current_mailing; normalized state = CAN."),
    "current_mailing_other": RelationMetadata("EDA mailing / 3_mailing_lists.sql", "Filtered current_mailing rows", ("current_mailing",), "Complete residual mailing projection.", "All columns inherited from current_mailing; includes NULL, blank, and states other than CA, TX, FL, NY, PA, and CAN."),
    "material_costs": RelationMetadata("EDA records / 3b_material_costs.sql", "One canonical Use period × section × ISBN item", ("course_materials_use", "pricing_wide"), "Approved item-level input with optional LEFT pricing enrichment."),
    "section_cost": RelationMetadata("EDA records / 4_merged_records.sql", "One material-bearing period × section", ("material_costs",), "Section-level price-bound aggregates used by release rollups."),
    "master_section": RelationMetadata("EDA records / 4_merged_records.sql", "One material-bearing period × section", ("material_costs", "section_cost", "section_enrollment", "course_materials"), "Canonical materialized per-term section release table."),
    "master_course": RelationMetadata("EDA records / 4_merged_records.sql", "One material-bearing period × course", ("master_section", "section_cost"), "Course-level section and cost rollup.", "Declared aggregate projection; no inherited base schema."),
    "master_course_material": RelationMetadata("EDA records / 4_merged_records.sql", "One (course_id, period_sortable, period, period_date, school, department, course_number, course_title, publisher, book_status) group", ("material_costs",), "Course material distribution rollup.", "Declared aggregate projection from material_costs."),
    "master_section_us_intro_fall2025": RelationMetadata("EDA records / 4_merged_records.sql", "Filtered master_section rows", ("master_section",), "Fall 2025 required intro/intermediate scope using the executable non-Canada/nonblank-state proxy.", "All columns inherited from master_section; filtered projection only."),
    "master_institution": RelationMetadata("Release model / models/master_institution.sql", "One period × institution, including an explicit NULL-institution bucket", ("master_section", "section_book_status", "pricing_wide"), "Canonical materialized per-term institution release table."),
    "master_isbn": RelationMetadata("Release model / models/master_isbn.sql", "One period × non-NULL ISBN", ("material_costs",), "Canonical materialized per-term ISBN release table."),
    "sample10_section_ids": RelationMetadata("Sampling / models/sample10_section_ids.sql", "One selected section_enrollment section", ("section_enrollment",), "Stable deterministic 10% section-membership lookup."),
    "__data_quality_metrics": RelationMetadata("Data quality / 2d_data_quality.sql", "One category × check × metric", ("course_catalog_20251215", "comprehensive_data", "pricing_historical", "pricing_wide", "BMG BookPricing.Historical_20260224.csv"), "Long-format pipeline quality metrics, including direct raw-pricing deduplication checks."),
    "__data_quality_top_unmatched_ipeds_schools": RelationMetadata("Data quality / 2d_data_quality.sql", "One ranked unmatched catalog school", ("course_catalog_20251215", "ipeds_data"), "Top unmatched IPEDS institution diagnostic."),
    "__data_quality_null_isbn_breakdown": RelationMetadata("Data quality / 2d_data_quality.sql", "One ranked catalog school", ("course_catalog_20251215",), "NULL-ISBN placeholder breakdown diagnostic."),
    "__data_quality_top_null_isbn_schools": RelationMetadata("Data quality / 2d_data_quality.sql", "One ranked catalog school", ("course_catalog_20251215",), "Top NULL-ISBN prevalence diagnostic."),
    "__data_quality_pricing_match_by_period": RelationMetadata("Data quality / 2d_data_quality.sql", "One pricing period", ("pricing_historical", "course_catalog_20251215"), "Exact section-and-ISBN pricing match diagnostic."),
    "__data_quality_top_unmatched_pricing_sections": RelationMetadata("Data quality / 2d_data_quality.sql", "One ranked institution × period", ("pricing_historical", "course_catalog_20251215"), "Top unmatched pricing-section diagnostic."),
    "__data_quality_format_count_distribution": RelationMetadata("Data quality / 2d_data_quality.sql", "One format_count value", ("pricing_wide",), "Wide-pricing format-count distribution diagnostic."),
}


# These SQL views use SELECT * from their base relation. Keeping the mapping explicit
# lets tests prevent DBML and generated documentation from silently drifting.
INHERITED_VIEW_BASES: dict[str, str] = {
    "course_materials_post_2024": "course_materials",
    "course_materials_use": "course_materials",
    "course_materials_no_use": "course_materials",
    "course_materials_canada": "course_materials",
    "current_mailing_ca": "current_mailing",
    "current_mailing_tx": "current_mailing",
    "current_mailing_fl": "current_mailing",
    "current_mailing_ny": "current_mailing",
    "current_mailing_pa": "current_mailing",
    "current_mailing_can": "current_mailing",
    "current_mailing_other": "current_mailing",
    "master_section_us_intro_fall2025": "master_section",
}

VIEW_FILTER_CONTEXT: dict[str, str] = {
    "course_materials_post_2024": "Rows where `is_post_2024` is true.",
    "course_materials_use": "Rows where `is_course_material_use` is true.",
    "course_materials_no_use": "Rows where `is_course_material_no_use` is true.",
    "course_materials_canada": "NoUse rows where `is_canada` is true.",
    "current_mailing_ca": "Rows whose normalized `state` is `CA`.",
    "current_mailing_tx": "Rows whose normalized `state` is `TX`.",
    "current_mailing_fl": "Rows whose normalized `state` is `FL`.",
    "current_mailing_ny": "Rows whose normalized `state` is `NY`.",
    "current_mailing_pa": "Rows whose normalized `state` is `PA`.",
    "current_mailing_can": "Rows whose normalized `state` is `CAN`.",
    "current_mailing_other": "Residual rows: state is NULL, blank, or outside CA/TX/FL/NY/PA/CAN.",
    "master_section_us_intro_fall2025": "Rows where `period_sortable = '2025-4'`, `required_count >= 1`, `course_level` is exactly `Introductory or general undergraduate` or `Intermediate undergraduate`, and non-NULL `state NOT IN ('CAN', '')`.",
}

# A small number of executable aggregate contracts are more precise than the
# legacy DBML prose and must remain accurate in the generated dictionary.
RELATION_NOTE_OVERRIDES: dict[str, str] = {
    "master_course_material": (
        "One row per (course_id × period_sortable × period × period_date × school × "
        "department × course_number × course_title × publisher × book_status), "
        "consumed directly from material_costs. SQL filters NULL course_id, publisher, "
        "and period_sortable before grouping; other group keys may be NULL."
    ),
}


_TABLE_RE = re.compile(
    r"^Table\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s+\[note:\s*'(table|view)'\])?\s*\{$"
)
_FIELD_RE = re.compile(
    r"^\s{2}([A-Za-z_][A-Za-z0-9_]*)\s+"
    r"([A-Za-z][A-Za-z0-9_]*(?:\([^)]*\))?(?:\[\])*)"
    r"(?:\s+\[(.*)\])?\s*$"
)
_NOTE_RE = re.compile(r"^\s{2}Note:\s*'(.*)'\s*$")
_FIELD_NOTE_RE = re.compile(r"(?:^|,\s*)note:\s*'(.*)'(?:\s*,|$)")


def _fail(path: Path, line_number: int, line: str, message: str) -> None:
    raise ValueError(f"{path}:{line_number}: {message}: {line!r}")


def parse_dbml(path: Path) -> list[Relation]:
    """Parse the supported canonical DBML subset, rejecting unknown syntax."""
    relations: list[Relation] = []
    relation: Relation | None = None
    block: str | None = None
    in_indexes = False
    in_triple_note = False

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.rstrip()
        stripped = line.strip()
        if in_triple_note:
            if stripped.endswith("'''"):
                in_triple_note = False
            continue
        if not stripped or stripped.startswith("//"):
            continue

        if relation is not None:
            if in_indexes:
                if stripped == "}":
                    in_indexes = False
                elif not re.fullmatch(
                    r"(?:[A-Za-z_][A-Za-z0-9_]*|\([^)]*\))\s*(?:\[.*\])?",
                    stripped,
                ):
                    _fail(path, line_number, line, "unsupported index syntax")
                continue
            if stripped == "indexes {":
                in_indexes = True
                continue
            if stripped == "}":
                relations.append(relation)
                relation = None
                continue
            note_match = _NOTE_RE.fullmatch(line)
            if note_match:
                relation.note = note_match.group(1).replace("''", "'")
                continue
            field_match = _FIELD_RE.fullmatch(line)
            if not field_match:
                _fail(path, line_number, line, "unsupported table-body syntax")
            settings = field_match.group(3) or ""
            note_match = _FIELD_NOTE_RE.search(settings)
            note = note_match.group(1).replace("''", "'") if note_match else None
            known_settings = settings
            if note_match:
                known_settings = settings[: note_match.start()] + settings[note_match.end() :]
            known_settings = known_settings.strip(" ,")
            if known_settings and any(
                part.strip() not in {"pk", "unique", "not null"}
                for part in known_settings.split(",")
            ):
                _fail(path, line_number, line, "unsupported column setting")
            relation.columns.append(Column(field_match.group(1), field_match.group(2), note))
            continue

        if block is not None:
            if stripped == "}":
                block = None
                continue
            if block == "project":
                if stripped.startswith("Note: '''"):
                    in_triple_note = not stripped.endswith("'''", len("Note: '''"))
                elif not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*:\s*'.*'", stripped):
                    _fail(path, line_number, line, "unsupported Project syntax")
            elif block == "enum":
                if not re.fullmatch(r'"[^"]+"(?:\s+\[note:\s*\'.*\'\])?', stripped):
                    _fail(path, line_number, line, "unsupported Enum syntax")
            elif block == "tablegroup":
                if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", stripped):
                    _fail(path, line_number, line, "unsupported TableGroup syntax")
            continue

        table_match = _TABLE_RE.fullmatch(stripped)
        if table_match:
            relation = Relation(
                name=table_match.group(1),
                kind="view" if table_match.group(2) == "view" else "table",
            )
        elif re.fullmatch(r"Project\s+[A-Za-z_][A-Za-z0-9_]*\s*\{", stripped):
            block = "project"
        elif re.fullmatch(r"Enum\s+[A-Za-z_][A-Za-z0-9_]*\s*\{", stripped):
            block = "enum"
        elif re.fullmatch(r"TableGroup\s+[A-Za-z_][A-Za-z0-9_]*\s*\{", stripped):
            block = "tablegroup"
        elif stripped.startswith("Ref:"):
            if not re.fullmatch(r"Ref:\s+.+\s+[<>-]\s+.+", stripped):
                _fail(path, line_number, line, "unsupported Ref syntax")
        else:
            _fail(path, line_number, line, "unsupported top-level DBML syntax")

    if relation is not None or block is not None or in_indexes or in_triple_note:
        raise ValueError(f"{path}: unclosed DBML block")
    names = [item.name for item in relations]
    if len(names) != len(set(names)):
        raise ValueError(f"{path}: duplicate Table declaration")
    return relations


def field_values(column: Column) -> str:
    """Return a semantic value/format description, never a type placeholder."""
    name = column.name.lower()
    data_type = column.data_type.lower()
    if name == "isbn13":
        structural = "ISBN or source identifier/pseudo-SKU represented in the declared relation type"
        return f"{column.note}; {structural}" if column.note else structural
    if column.note:
        return column.note
    if name == "period_sortable":
        return "`YYYY-N`; 1=Winter, 2=Spring, 3=Summer, 4=Fall"
    if name == "period":
        return 'Academic term label such as `Fall 2024`'
    if name == "period_date":
        return "Canonical date: YYYY-01-01, YYYY-04-01, YYYY-07-01, or YYYY-10-01"
    if name == "isbn13":
        return "ISBN or source identifier/pseudo-SKU represented in the declared relation type"
    if name in {"unit_id", "unitid"}:
        return "IPEDS institution identifier"
    if name == "course_id":
        return "`unit_id::department-code::course-number` composite"
    if name == "section_id":
        return "`course_id::section-code::period_sortable` composite"
    if name == "email":
        return "Lowercase, trimmed email text"
    if name == "enrollment_source":
        return "`own`, `own_seats`, `sibling_enroll`, `sibling_seats`, `class_median`, `level_median`, or `none`"
    if name == "book_option":
        return "`buy` or `rental`"
    if name == "book_condition":
        return "`new`, `used`, or unavailable condition"
    if name in {"book_format", "format"}:
        return "Source material format; pricing uses `physical`, `digital`, or unavailable format"
    if name == "book_status":
        return "Lowercase `required`, `recommended`, `option`, or missing status"
    if name == "sample_bucket":
        return "Whole number 0–9; bucket 0 is the deterministic 10% sample"
    if name == "section_hash":
        return "Unsigned 64-bit value from the first 16 hexadecimal MD5 characters"
    if name.endswith("_pct") or name == "match_pct":
        return "Percentage from 0 through 100"
    if name.endswith("_count") or name.endswith("_rows") or name.endswith("_tot") or name in {
        "catalog_rows", "other", "unmatched", "pricing_sections", "rows_matched",
        "total_rows", "total_null_isbn", "distinct_sections", "enroll_cnt", "enroll_tot",
        "material_instances", "sections_using", "total_seats_affected", "metric_value",
    }:
        return "Non-negative whole-number count"
    if "price" in name or "cost" in name:
        return "USD decimal at the precision declared in DBML"
    if data_type == "boolean":
        return "TRUE or FALSE"
    if data_type == "date":
        return "Calendar date in YYYY-MM-DD form"
    if data_type.startswith("timestamp"):
        return "Timestamp parsed from the source pricing snapshot"
    if data_type.endswith("[][]"):
        return "Nested list retaining the upstream grouped list values"
    if data_type.endswith("[]"):
        return "List of distinct nonmissing source values"
    if data_type in {"integer", "bigint", "hugeint", "ubigint", "utinyint"}:
        return "Whole number in the declared integer range"
    if data_type in {"decimal", "double", "float", "real"}:
        return "Decimal measure in the units named by the field"
    label = name.replace("_", " ")
    return f"{label.capitalize()} text; spelling/casing follows the stated source or derivation"


CATALOG_EXTERNAL_FIELDS: dict[str, str] = {
    "ISBN13": "ISBN13", "Title": "Title", "Author": "Author", "Publisher": "Publisher",
    "Imprint": "Imprint", "Format": "Format", "FormatType": "FormatType",
    "book_status": "Book Status", "unit_id": "IPED ID", "school": "School",
    "state": "State", "dept_code": "Dept Code", "department": "Department",
    "dept_description": "Dept Description", "course_number": "Course Number",
    "section": "Section", "course_title": "Course Title", "course_level": "Course Level",
    "course_subject": "Course Subject", "period": "Period", "enrollments": "Enrollments",
    "seats_taken": "Seats Taken", "instructor": "Instructor", "first_name": "FirstName",
    "last_name": "LastName", "email": "E-Mail",
}

PRICING_EXTERNAL_FIELDS: dict[str, str] = {
    "unit_id": "IPEDSID", "institute": "Institute", "bookstore_url": "Address",
    "pricing_date": "Book Pricing Date", "period": "Period", "dept_code": "Department Code",
    "dept_name": "Department Name", "course_code": "Course Code", "section_code": "Section Code",
    "crn": "CRN", "instructor_name": "Instructor Name", "isbn13": "ISBN13", "title": "Title",
    "author": "Author", "publisher": "Publisher", "edition": "Edition",
    "book_status": "Book Status", "book_option": "Book Option",
    "book_condition": "Book Condition", "book_format": "Book Format", "price": "Price",
    "rental_days": "Rental Length", "return_date": "Return Date",
}

IPEDS_EXTERNAL_FIELDS = {
    "unitid": "UNITID", "instnm": "INSTNM", "sector": "SECTOR", "iclevel": "ICLEVEL",
    "control": "CONTROL", "instsize": "INSTSIZE", "enroll_24": "Enroll_24",
    "dist_enroll_24": "DistEnroll_24", "inst_type": "InstType",
}

COURSE_MATERIAL_DERIVED_FIELDS = {
    "isbn_book_title", "isbn_author", "isbn_publisher", "isbn_title_variant_count",
    "isbn_author_variant_count", "isbn_publisher_variant_count", "has_enrollment_sibling",
    "has_enrollment_sibling_seats", "enrollment_assigned", "enrollment_source",
    "has_book_status_required", "has_book_status_optional_recommended", "source_row_count",
    "title_variant_count", "author_variant_count", "publisher_variant_count",
    "imprint_variant_count", "book_format_variant_count", "format_type_variant_count",
    "book_status_variant_count", "catalog_metadata_conflict", "is_required_inferred_conflict",
    "is_oer_conflict", "is_ia_conflict", "use_source_row_count", "no_use_source_row_count",
    "has_use_source_row", "has_no_use_source_row", "population_classification_conflict",
    "instructor_variant_count", "email_variant_count", "contact_metadata_conflict",
    "is_supply_conflict", "no_details_conflict", "no_materials_conflict", "is_canada_conflict",
    "is_null_isbn_audit", "has_nonnull_isbn_in_section", "is_no_adoption_section",
}


def _metadata(
    column: Column,
    source: str,
    population: str,
    null_meaning: str,
    kind: str,
    values: str | None = None,
) -> FieldMetadata:
    return FieldMetadata(source, values or field_values(column), population, null_meaning, kind)


def parse_master_section_metadata(appendix_body: str) -> dict[str, tuple[str, str, str]]:
    """Read the authoritative field rows from the maintained appendix tables."""
    rows: dict[str, tuple[str, str, str]] = {}
    for line in appendix_body.splitlines():
        if not re.match(r"^\| `[^`]+` \|", line):
            continue
        cells = [cell.strip().replace("\\|", "|") for cell in line.strip().strip("|").split("|")]
        if len(cells) != 5:
            raise ValueError(f"unsupported Master Section appendix row: {line!r}")
        name = cells[0].strip("`")
        if name in rows:
            raise ValueError(f"duplicate Master Section appendix field: {name}")
        rows[name] = (cells[2], cells[3], cells[4])
    if not rows:
        raise ValueError("Master Section appendix contains no field metadata rows")
    return rows


def _source_import_metadata(relation: str, column: Column) -> FieldMetadata | None:
    name = column.name
    if relation == "course_catalog_20251215":
        if name in CATALOG_EXTERNAL_FIELDS:
            external = CATALOG_EXTERNAL_FIELDS[name]
            normalization = {
                "book_status": "lowercase + trim",
                "email": "extract/clean first address, remove embedded spaces, lowercase + trim",
                "enrollments": "TRY_CAST to INTEGER",
                "seats_taken": "TRY_CAST to INTEGER",
            }.get(name, "direct CSV import; configured null tokens become NULL")
            return _metadata(column, f'BMG Discovery Extract field `{external}`; {normalization}.',
                             "One normalized Discovery Extract row.",
                             "External field absent, blank, a configured null token, or failed TRY_CAST where applicable.", "source")
        if name in {"course_id", "section_id", "period_sortable", "period_date"}:
            expressions = {
                "course_id": "Concatenate normalized `IPED ID`, `Dept Code`, and `Course Number` with `::`; missing segments become `UNKNOWN`.",
                "section_id": "Concatenate `course_id`, normalized `Section`, and derived term with `::`; missing segments become `UNKNOWN`.",
                "period_sortable": "Map `Period` season/year to `YYYY-N` (Winter=1 through Fall=4).",
                "period_date": "Map `Period` to the canonical first day for its season.",
            }
            nulls = "Unrecognized or missing academic-period text." if name.startswith("period_") else "Not produced; missing composite segments are encoded as `UNKNOWN`."
            return _metadata(column, expressions[name], "One normalized Discovery Extract row.", nulls, "derived")
    if relation == "ipeds_data" and name in IPEDS_EXTERNAL_FIELDS:
        ext = IPEDS_EXTERNAL_FIELDS[name]
        cast = "TRY_CAST to INTEGER; " if name in {"unitid", "enroll_24", "dist_enroll_24"} else ""
        return _metadata(column, f"IPEDS field `{ext}`; {cast}configured null tokens normalized.",
                         "One IPEDS institution source row.", "IPEDS field unavailable, configured as missing, or failed TRY_CAST.", "source")
    if relation == "opt_out" and name in {"email", "source"}:
        ext = "Email" if name == "email" else "Source"
        norm = "lowercase + trim" if name == "email" else "direct import"
        return _metadata(column, f"BVA opt-out field `{ext}`; {norm}.", "One BVA opt-out source row.",
                         "External field absent or normalized from a configured null token.", "source")
    if relation == "panel" and name in {"email", "response_year"}:
        ext = "Unique" if name == "email" else "Year"
        norm = "lowercase + trim" if name == "email" else "direct import"
        return _metadata(column, f"BVA panel field `{ext}`; {norm}.", "One retained BVA panel-history row.",
                         "External field absent or normalized from a configured null token.", "source")
    if relation == "pricing_historical":
        if name in PRICING_EXTERNAL_FIELDS:
            ext = PRICING_EXTERNAL_FIELDS[name]
            norm = "lowercase + trim" if name in {"book_status", "book_option", "book_condition", "book_format"} else "trim"
            if name in {"unit_id", "pricing_date", "price", "rental_days", "return_date"}:
                norm = f"{norm} and TRY_CAST to the declared type"
            return _metadata(column, f"BMG Book Pricing field `{ext}`; {norm}; latest logical-key snapshot retained after duplicate/instructor collapse.",
                             "Latest section×ISBN×option×condition×format×rental-term source observation.",
                             "External field absent, a configured null token, or failed TRY_CAST.", "source")
        if name == "required":
            return _metadata(column, "`LOWER(TRIM(Book Status)) = 'required'` during pricing import.",
                             "Each retained pricing observation.", "NULL when Book Status is missing; TRUE only for required, FALSE for non-NULL non-required status.", "derived")
        if name in {"course_id", "section_id", "period_sortable", "period_date"}:
            source = {
                "course_id": "Composite of `IPEDSID`, `Department Code`, and `Course Code`; missing segments encoded `UNKNOWN`.",
                "section_id": "Composite of course components, `Section Code`, and derived sortable period; missing segments encoded `UNKNOWN`.",
                "period_sortable": "Season/year parsed from pricing field `Period` to `YYYY-N`.",
                "period_date": "Season/year parsed from pricing field `Period` to canonical season date.",
            }[name]
            nulls = "Unrecognized or missing pricing-period text." if name.startswith("period_") else "Not produced; missing composite segments are encoded as `UNKNOWN`."
            return _metadata(column, source, "Each retained pricing observation.", nulls, "derived")
    return None


def resolve_field_metadata(
    relations: list[Relation], appendix_body: str
) -> dict[tuple[str, str], FieldMetadata]:
    """Resolve every canonical DBML field or fail on the first unregistered field."""
    by_name = {relation.name: relation for relation in relations}
    appendix = parse_master_section_metadata(appendix_body)
    if "master_section" not in by_name:
        raise ValueError("schema has no master_section relation")
    master_names = {column.name for column in by_name["master_section"].columns}
    if master_names != set(appendix):
        raise ValueError(
            "Master Section appendix coverage mismatch; "
            f"missing={sorted(master_names - set(appendix))}, extra={sorted(set(appendix) - master_names)}"
        )

    resolved: dict[tuple[str, str], FieldMetadata] = {}
    resolving: set[str] = set()

    def relation_fields(relation_name: str) -> None:
        if all((relation_name, c.name) in resolved for c in by_name[relation_name].columns):
            return
        if relation_name in resolving:
            raise ValueError(f"cyclic field metadata inheritance at {relation_name}")
        resolving.add(relation_name)
        relation = by_name[relation_name]
        if relation_name in INHERITED_VIEW_BASES:
            base_name = INHERITED_VIEW_BASES[relation_name]
            relation_fields(base_name)
            base = by_name[base_name]
            if [(c.name, c.data_type) for c in relation.columns] != [(c.name, c.data_type) for c in base.columns]:
                raise ValueError(f"inherited view schema mismatch: {relation_name} != {base_name}")
            context = VIEW_FILTER_CONTEXT[relation_name]
            for column in relation.columns:
                inherited = resolved[(base_name, column.name)]
                resolved[(relation_name, column.name)] = FieldMetadata(
                    f"Inherited unchanged from `{base_name}.{column.name}` (`SELECT *`).",
                    inherited.values,
                    f"{inherited.population} View context: {context}",
                    inherited.null_meaning,
                    "inherited",
                )
            resolving.remove(relation_name)
            return

        for column in relation.columns:
            item = _resolve_non_inherited(relation, column, resolved, by_name, appendix)
            if item is None:
                raise ValueError(f"unregistered DBML field: {relation.name}.{column.name}")
            for label, value in (
                ("source", item.source), ("values", item.values),
                ("population", item.population), ("NULL meaning", item.null_meaning),
            ):
                if not value.strip():
                    raise ValueError(f"empty {label} metadata: {relation.name}.{column.name}")
            resolved[(relation.name, column.name)] = item
        resolving.remove(relation_name)

    for relation in relations:
        relation_fields(relation.name)
    return resolved


def _resolve_non_inherited(
    relation: Relation,
    column: Column,
    resolved: dict[tuple[str, str], FieldMetadata],
    by_name: dict[str, Relation],
    appendix: dict[str, tuple[str, str, str]],
) -> FieldMetadata | None:
    r, n = relation.name, column.name
    imported = _source_import_metadata(r, column)
    if imported:
        return imported
    if r == "panel_email":
        if n == "email":
            return _metadata(column, "Group key from normalized `panel.email`.", "One cleaned panel email.", "Not expected; NULL emails group together if present in source.", "aggregate")
        rules = {
            "panel_response_year": ("`MAX(panel.response_year)`.", "No nonmissing response year for the email."),
            "panel_source_row_count": ("`COUNT(*)` of retained panel rows.", "Never NULL; at least one."),
            "panel_response_year_variant_count": ("`COUNT(DISTINCT panel.response_year)`.", "Never NULL; zero means all years missing."),
        }
        if n in rules:
            return _metadata(column, rules[n][0], "All retained panel-history rows for the cleaned email.", rules[n][1], "aggregate")
    if r == "format_type_classification" and n in {"FormatType", "is_oer", "oer_category", "is_ia", "ia_category"}:
        ext = {"FormatType": "format_type"}.get(n, n)
        cast = " cast to BOOLEAN" if n in {"is_oer", "is_ia"} else ""
        return _metadata(column, f"Lookup TSV field `{ext}`; direct tab-delimited import{cast}.", "One format-type classification lookup row.", "Lookup cell missing.", "source")
    if r == "supply_isbn_classification":
        rules = {
            "isbn13": "Non-NULL catalog ISBN group key after qualifying title-pattern matches.",
            "title": "Deterministic representative catalog title for the ISBN.",
            "n_rows": "Count of 2024+ catalog rows covered by qualifying title variants.",
            "matched_pattern": "Highest-priority included lowercase keyword; longest then lexical tie-break.",
            "category": "Category attached to the selected supply keyword.",
        }
        if n in rules:
            null = "Not produced." if n in {"isbn13", "n_rows", "matched_pattern", "category"} else "No representative nonmissing title."
            return _metadata(column, rules[n], "One classified non-NULL ISBN in the 2024+ catalog.", null, "aggregate")
    if r == "section_book_status" and n in {"section_id", "has_required"}:
        source = "Group key from `course_catalog_20251215.section_id`." if n == "section_id" else "`BOOL_OR(book_status='required' AND NOT is_supply)` over catalog rows."
        null = "Not produced." if n == "section_id" else "Never NULL; false means no nonsupply required-status row."
        return _metadata(column, source, "All catalog rows for the period-specific section.", null, "aggregate")
    if r == "state_region" and n in {"state", "region", "division"}:
        return _metadata(column, f"Maintained static `{n}` value in `0b_state_region.sql`.", "One state/province code lookup row.", "Not produced by the static lookup.", "explicit")
    if r == "pricing_wide":
        return _pricing_wide_metadata(column)
    if r == "comprehensive_data":
        catalog = {c.name: c for c in by_name["course_catalog_20251215"].columns}
        if n in catalog:
            base = _source_import_metadata("course_catalog_20251215", catalog[n])
            assert base
            return FieldMetadata(f"Passthrough from `course_catalog_20251215.{n}`.", base.values,
                                 "One enriched normalized catalog source row.", base.null_meaning, "passthrough")
        return _comprehensive_metadata(column)
    if r == "course_materials":
        return _course_materials_metadata(column, by_name)
    if r == "section_enrollment":
        return _section_enrollment_metadata(column)
    if r in {"master_mailing", "current_mailing", "recent_periods"}:
        return _mailing_metadata(r, column)
    if r == "material_costs":
        cm_names = {c.name for c in by_name["course_materials"].columns}
        pw_names = {c.name for c in by_name["pricing_wide"].columns}
        if n in cm_names:
            base = resolved.get(("course_materials", n))
            if base is None:
                base_col = next(c for c in by_name["course_materials"].columns if c.name == n)
                base = _course_materials_metadata(base_col, by_name)
            assert base
            return FieldMetadata(f"Passthrough from `course_materials_use.{n}`.", base.values,
                                 "Canonical Use section×ISBN items retained by `material_costs`.", base.null_meaning, "passthrough")
        if n in pw_names:
            base_col = next(c for c in by_name["pricing_wide"].columns if c.name == n)
            base = _pricing_wide_metadata(base_col)
            assert base
            return FieldMetadata(f"LEFT JOIN passthrough from `pricing_wide.{n}` on `(section_id, isbn13)`.", base.values,
                                 "Canonical Use items; pricing is optional exact-match enrichment.",
                                 "No exact pricing row, or the matched pricing aggregate has no valid value.", "joined")
        if n == "has_pricing_match":
            return _metadata(column, "`pricing_wide.section_id IS NOT NULL` after the exact `(section_id, isbn13)` LEFT JOIN.",
                             "Every canonical Use item.", "Never NULL; false distinguishes no pricing match.", "joined")
    if r == "section_cost":
        return _section_cost_metadata(column)
    if r == "master_section" and n in appendix:
        source, population, null = appendix[n]
        return _metadata(column, source, population, null, "appendix")
    if r == "master_course":
        return _master_course_metadata(column)
    if r == "master_course_material":
        return _master_course_material_metadata(column)
    if r == "master_institution":
        return _master_institution_metadata(column)
    if r == "master_isbn":
        return _master_isbn_metadata(column)
    if r == "sample10_section_ids":
        rules = {
            "section_id": ("Distinct `section_enrollment.section_id` group key.", "Not produced."),
            "period_sortable": ("`ANY_VALUE(section_enrollment.period_sortable)` for the section.", "Not expected for retained section_enrollment rows."),
            "section_hash": ("Unsigned integer from `CAST('0x' || LEFT(md5(section_id),16) AS UBIGINT)`.", "Not produced."),
            "sample_bucket": ("`section_hash % 10`, cast to UTINYINT.", "Not produced."),
        }
        if n in rules:
            return _metadata(column, rules[n][0], "Distinct complete-population section IDs.", rules[n][1], "derived")
    if r.startswith("__data_quality_"):
        return _dq_metadata(r, column)
    return None


def _pricing_wide_metadata(column: Column) -> FieldMetadata | None:
    n = column.name
    pop = "All retained pricing observations for one `(section_id, isbn13)` group."
    direct = {"section_id", "isbn13"}
    max_fields = {"unit_id", "institute", "bookstore_url", "title", "author", "publisher", "edition"}
    if n in direct:
        return _metadata(column, f"Group key from `pricing_historical.{n}`.", pop, "Not produced for a retained group.", "aggregate")
    if n in max_fields:
        return _metadata(column, f"`MAX(pricing_historical.{n})` for source provenance/metadata.", pop, "No nonmissing value in the group.", "aggregate")
    if n == "required":
        return _metadata(column, "`BOOL_OR(pricing_historical.required)`.", pop, "NULL when every retained row has required = NULL (for example, Book Status is missing); otherwise TRUE if any row is required and FALSE when all non-NULL values are false.", "aggregate")
    match = re.fullmatch(r"price_(buy|rental)_(new|used|na)_(physical|digital|na)", n)
    if match:
        option, condition, fmt = match.groups()
        condition_sql = "book_condition IS NULL" if condition == "na" else f"book_condition = '{condition}'"
        format_sql = "book_format IS NULL" if fmt == "na" else f"book_format = '{fmt}'"
        return _metadata(column, f"`MAX(price)` where `book_option = '{option}'`, `{condition_sql}`, and `{format_sql}` after prices >=9999 are normalized to NULL.", pop,
                         "That option/condition/format has no price below the 9999 sentinel ceiling.", "aggregate")
    rules = {
        "format_count": ("`COUNT(DISTINCT book_option || ':' || condition || ':' || format)` for buy/rental listings.", "Never NULL; zero means no offered tuple."),
        "has_buy": ("`BOOL_OR(book_option='buy')`.", "NULL when every retained row has book_option = NULL; otherwise TRUE if any row is buy and FALSE when all non-NULL values are not buy."),
        "has_rent": ("`BOOL_OR(book_option='rental')`.", "NULL when every retained row has book_option = NULL; otherwise TRUE if any row is rental and FALSE when all non-NULL values are not rental."),
        "price_min": ("`MIN(price)` after prices >=9999 are normalized to NULL; zero is retained.", "No price below the 9999 sentinel ceiling in the group."),
        "price_max": ("`MAX(price)` after prices >=9999 are normalized to NULL; zero is retained.", "No price below the 9999 sentinel ceiling in the group."),
        "price_avg": ("Legacy midpoint `(price_min + price_max) / 2.0`; not AVG().", "Either price bound is missing."),
        "rental_days_min": ("Minimum nonmissing rental term.", "No listing has an explicit rental term."),
        "rental_days_max": ("Maximum nonmissing rental term.", "No listing has an explicit rental term."),
        "price_buy_min": ("`MIN(price)` FILTERed to buy after prices >=9999 become NULL; rentals excluded.", "No buy price below the 9999 sentinel ceiling."),
        "price_buy_max": ("`MAX(price)` FILTERed to buy after prices >=9999 become NULL; rentals excluded.", "No buy price below the 9999 sentinel ceiling."),
    }
    if n in rules:
        return _metadata(column, rules[n][0], pop, rules[n][1], "aggregate")
    return None


def _comprehensive_metadata(column: Column) -> FieldMetadata | None:
    n = column.name
    pop = "One enriched normalized catalog source row."
    joins = {
        "is_oer": "`format_type_classification.is_oer` joined on exact `FormatType`.",
        "oer_category": "Joined OER category, coalesced to `unknown`.",
        "is_ia": "`format_type_classification.is_ia` joined on exact `FormatType`.",
        "ia_category": "Joined IA category, coalesced to `unknown`.",
        "is_supply": "True when catalog ISBN matches `supply_isbn_classification`; unmatched/NULL ISBN is false.",
        "supply_category": "Category from the matched `supply_isbn_classification` row.",
        "institution_name": "`ipeds_data.instnm` joined on `unit_id = unitid`.",
        "sector": "`ipeds_data.sector` joined on institution ID.", "level": "`ipeds_data.iclevel` joined on institution ID.",
        "control": "`ipeds_data.control` joined on institution ID.", "size": "`ipeds_data.instsize` joined on institution ID.",
        "enrollment_2024": "`ipeds_data.enroll_24` joined on institution ID.",
        "distance_enrollment_2024": "`ipeds_data.dist_enroll_24` joined on institution ID.",
        "institution_type": "`ipeds_data.inst_type` joined on institution ID.",
        "panel_response_year": "`panel_email.panel_response_year` joined on cleaned email.",
        "panel_source_row_count": "`panel_email.panel_source_row_count` joined on cleaned email.",
        "panel_response_year_variant_count": "`panel_email.panel_response_year_variant_count` joined on cleaned email.",
        "is_opted_out": "True when cleaned email matches `opt_out`; otherwise false.",
        "opt_out_source": "`opt_out.source` joined on cleaned email.",
        "is_required_inferred": "True for 2024+ rows satisfying supply-aware section required-status fallback.",
        "is_post_2024": "`COALESCE(period_date >= DATE '2024-01-01', FALSE)`.",
        "has_isbn": "`ISBN13 IS NOT NULL`.", "has_formattype": "`FormatType` is non-NULL and nonblank.",
        "has_enrollment": "`enrollments IS NOT NULL`.",
        "has_enrollment_own_seats": "`seats_taken IS NOT NULL AND seats_taken < 9999`.",
        "no_details": "Title equals exact marker `*No Book Details*`.",
        "no_materials": "Title equals `*No Books Required*` or supply category is `placeholder_no_material`.",
        "is_canada": "`state = 'CAN'`, coalesced false.",
        "is_course_material_use": "2024+ AND not Canada AND has ISBN AND not supply/no-details/no-materials.",
        "is_course_material_no_use": "2024+ complement of `is_course_material_use`; false before 2024.",
    }
    if n not in joins:
        return None
    nullable_join = n in {"is_oer", "is_ia", "supply_category", "institution_name", "sector", "level", "control", "size", "enrollment_2024", "distance_enrollment_2024", "institution_type", "panel_response_year", "panel_source_row_count", "panel_response_year_variant_count", "opt_out_source"}
    null = "No matching lookup row or the matched lookup value is missing." if nullable_join else "Never NULL; false represents absence or exclusion."
    return _metadata(column, joins[n], pop, null, "joined" if nullable_join else "derived")


def _course_materials_metadata(column: Column, by_name: dict[str, Relation]) -> FieldMetadata | None:
    n = column.name
    pop = "Catalog rows grouped at period×section×ISBN; one NULL-ISBN audit group when present."
    rename = {"isbn13": "ISBN13", "book_title": "Title", "author": "Author", "publisher": "Publisher", "imprint": "Imprint", "book_format": "Format", "format_type": "FormatType"}
    comprehensive = {c.name for c in by_name["comprehensive_data"].columns}
    source_name = rename.get(n, n)
    if n in {"isbn13", "section_id", "period_sortable"}:
        cast = " and cast to BIGINT" if n == "isbn13" else ""
        return _metadata(column, f"Group key from `comprehensive_data.{source_name}`{cast}.", pop,
                         "ISBN is NULL only on audit groups; section and sortable-period keys are required.", "aggregate")
    definitive = {
        "is_required_inferred", "is_oer", "is_ia", "is_supply", "is_post_2024",
        "has_formattype", "no_details", "no_materials", "is_canada",
        "has_book_status_required", "has_book_status_optional_recommended",
        "has_use_source_row", "has_no_use_source_row",
    }
    if n in definitive:
        expression = {
            "has_book_status_required": "book_status = 'required'",
            "has_book_status_optional_recommended": "book_status IN ('option','recommended')",
            "has_use_source_row": "is_course_material_use",
            "has_no_use_source_row": "is_course_material_no_use",
        }.get(n, n)
        return _metadata(column, f"`BOOL_OR({expression})` across grouped `comprehensive_data` rows.", pop,
                         "Never NULL under the normalized row-flag contract; false means no grouped row qualifies.", "aggregate")
    if n == "has_isbn":
        return _metadata(column, "Grouped ISBN key `IS NOT NULL`.", pop,
                         "Never NULL; false identifies the NULL-ISBN audit group.", "derived")
    if n == "is_course_material_use":
        return _metadata(column, "Exact alias of grouped `has_use_source_row`.", pop,
                         "Never NULL; false means no grouped raw row is in Use.", "derived")
    if n == "is_course_material_no_use":
        return _metadata(column, "`is_post_2024 AND NOT has_use_source_row` at canonical item grain.", pop,
                         "Never NULL; false includes pre-2024 groups and Use groups.", "derived")
    section_owned = {"course_level", "enrollments", "seats_taken", "course_id", "sector", "level", "control", "has_enrollment", "has_enrollment_own_seats"}
    if n in section_owned:
        return _metadata(column, f"`COALESCE(section_enrollment.{n}, representative comprehensive_data.{source_name})`.", pop,
                         "Neither the section-canonical value nor representative source row has a value.", "joined")
    if source_name in comprehensive and n not in COURSE_MATERIAL_DERIVED_FIELDS:
        return _metadata(column, f"Deterministic representative `comprehensive_data.{source_name}` from the grouped source rows.", pop,
                         "No grouped source row has a nonmissing representative value.", "aggregate")
    if n not in COURSE_MATERIAL_DERIVED_FIELDS:
        return None
    if n.startswith("isbn_") and n.endswith("_variant_count"):
        attr = n.removeprefix("isbn_").removesuffix("_variant_count")
        return _metadata(column, f"Distinct nonmissing `{attr}` variants across all catalog rows for `(period_sortable, isbn13)`.",
                         "All catalog rows for the term×ISBN.", "Never NULL; zero means no nonmissing value.", "aggregate")
    if n in {"isbn_book_title", "isbn_author", "isbn_publisher"}:
        attr = {"isbn_book_title": "Title", "isbn_author": "Author", "isbn_publisher": "Publisher"}[n]
        return _metadata(column, f"Lexical `MIN(NULLIF(TRIM({attr}),''))` across Use catalog rows for `(period_sortable, isbn13)`.",
                         "All catalog rows for the term×ISBN.", "No nonmissing metadata value for the term×ISBN.", "aggregate")
    if n == "enrollment_assigned" or n == "enrollment_source" or n.startswith("has_enrollment_sibling"):
        return _metadata(column, f"Exact `{n}` from `section_enrollment` joined by section ID.", pop,
                         "Only `enrollment_assigned` is nullable: no assignment ladder rung produced a value; flags/source are non-NULL.", "joined")
    if n.endswith("_variant_count"):
        attr = n.removesuffix("_variant_count")
        return _metadata(column, f"Count of distinct nonmissing `{attr}` values among duplicate catalog rows for the group.", pop,
                         "Never NULL; zero means no nonmissing value.", "aggregate")
    if n.endswith("_source_row_count") or n == "source_row_count":
        qualifier = "Use" if n.startswith("use_") else "NoUse" if n.startswith("no_use_") else "all"
        null_meaning = (
            "Never NULL or zero for a retained group."
            if n == "source_row_count"
            else "Never NULL; zero is possible for the filtered count."
        )
        return _metadata(column, f"Count of {qualifier} `comprehensive_data` rows in the group.", pop, null_meaning, "aggregate")
    exact_conflicts = {
        "catalog_metadata_conflict": "True when any title/author/publisher/imprint/format/FormatType/book-status variant count exceeds one.",
        "population_classification_conflict": "True when both Use and NoUse source-row counts exceed zero.",
        "contact_metadata_conflict": "True when instructor or email variant count exceeds one.",
    }
    if n in exact_conflicts:
        return _metadata(column, exact_conflicts[n], pop,
                         "Never NULL; false means the named conflict was not detected.", "dq")
    if n.endswith("_conflict"):
        basis = n.removesuffix("_conflict")
        return _metadata(column, f"DQ flag: grouped `{basis}` evidence disagrees (BOOL_OR distinct from BOOL_AND, or component conflict OR as applicable).", pop,
                         "Never NULL; false means no detected within-group conflict.", "dq")
    rules = {
        "is_null_isbn_audit": "True when grouped ISBN is NULL.",
        "has_nonnull_isbn_in_section": "Section-level `BOOL_OR(isbn13 IS NOT NULL)` across grouped items.",
        "is_no_adoption_section": "NULL-ISBN audit row in a section with no non-NULL ISBN.",
    }
    if n in rules:
        return _metadata(column, rules[n], pop, "Never NULL; false means the named evidence is absent.", "aggregate")
    return None


def _section_enrollment_metadata(column: Column) -> FieldMetadata | None:
    n = column.name
    pop = "All valid 2024+ catalog rows for one period-specific section; independent of material inclusion."
    if n in {"section_id", "course_id", "period_sortable", "control", "level", "sector", "course_level"}:
        func = "group key" if n == "section_id" else "deterministic section value (`ANY_VALUE` or lexical `mode` as defined in SQL)"
        return _metadata(column, f"{func.capitalize()} from `comprehensive_data.{n}`.", pop,
                         "Missing upstream descriptor; section and sortable-period keys are required.", "aggregate")
    if n in {"enrollments", "seats_taken"}:
        return _metadata(column, f"`MAX(comprehensive_data.{n})` for the section; raw 9999 seats sentinel retained.", pop,
                         f"No reported {n.replace('_', ' ')}.", "aggregate")
    flag_expr = {
        "has_enrollment": "section MAX(enrollments) is non-NULL",
        "has_enrollment_own_seats": "section MAX(seats_taken) is non-NULL and below 9999",
        "has_enrollment_sibling": "another same-course/same-term section has enrollment",
        "has_enrollment_sibling_seats": "another same-course/same-term section has valid seats",
    }
    if n in flag_expr:
        return _metadata(column, flag_expr[n].capitalize() + ".", pop, "Never NULL; false means the signal is absent.", "derived")
    if n == "enrollment_assigned":
        return _metadata(column, "Rounded first available: own enrollment, own valid seats, course enrollment median, course seats median, control×level median, level median.", pop,
                         "No assignment ladder rung produced a value (`enrollment_source='none'`).", "derived")
    if n == "enrollment_source":
        return _metadata(column, "Label for the first successful enrollment-assignment ladder rung.", pop, "Never NULL; `none` means unassigned.", "derived")
    return None


def _mailing_metadata(relation: str, column: Column) -> FieldMetadata | None:
    n = column.name
    if relation == "recent_periods" and n == "period_sortable":
        return _metadata(column, "Latest 12 distinct nonmissing `master_mailing.period_sortable` values.", "One retained recent term boundary from the persisted master selection.", "Not produced.", "aggregate")
    base_fields = {"unit_id", "school", "state", "department", "course_level", "course_subject", "period", "period_sortable", "period_date", "instructor", "first_name", "last_name", "email"}
    if n in base_fields:
        if relation == "master_mailing":
            null_meaning = "Not produced; retained master emails are required." if n == "email" else "Selected source row has no value for this field."
            return _metadata(column, f"Deterministically selected `course_catalog_20251215.{n}` directly from `${{SURVEY_TABLE}}` for each cleaned email.",
                             "All normalized catalog rows sharing one non-NULL, nonblank cleaned email; opt_out and panel history do not participate.", null_meaning, "aggregate")
        if relation == "current_mailing":
            null_meaning = "Not produced; retained current emails are required." if n == "email" else "Selected master row has no value for this field."
            return _metadata(column, f"Passthrough from `master_mailing.{n}` after membership in `recent_periods` and `NOT EXISTS` exclusion by `opt_out.email`.",
                             "Master-selected emails in the latest 12 selected periods that have no opt_out match.", null_meaning, "passthrough")
    if relation == "current_mailing" and n == "panel_response_year":
        return _metadata(column, "`panel_email.panel_response_year` LEFT JOINed to `master_mailing` by cleaned email.",
                         "Master-selected emails in recent_periods with no opt_out match.", "No recorded panel response year for the email.", "joined")
    return None


def _section_cost_metadata(column: Column) -> FieldMetadata | None:
    n = column.name
    pop = "Distinct canonical Use ISBN items in one section."
    if n in {"section_id", "course_id", "period_sortable"}:
        return _metadata(column, f"Group key / constant value from `material_costs.{n}`.", pop, "Not expected for retained material items.", "aggregate")
    match = re.fullmatch(r"(required|optional)_cost_(total|owned)_(min|max)", n)
    if match:
        status, scope, bound = match.groups()
        price = f"price_{bound}" if scope == "total" else f"price_buy_{bound}"
        return _metadata(column, f"SUM of distinct `{price}` for {status} canonical ISBN items; {scope} scope.",
                         f"{status.capitalize()} canonical items with a nonmissing {scope} {bound} price.",
                         f"No {status} item has a valid {scope} price.", "aggregate")
    if n in {"required_priced_count", "optional_priced_count"}:
        status = n.split("_", 1)[0]
        return _metadata(column, f"Count of {status} canonical ISBN items with non-NULL `price_min`.",
                         f"All {status} canonical items in the section.", "Never NULL; zero means none priced.", "aggregate")
    return None


def _master_course_metadata(column: Column) -> FieldMetadata | None:
    n = column.name
    pop = "Material-bearing `master_section` rows for one course×term."
    if n in {"course_id", "period_sortable"}:
        return _metadata(column, f"Group key from `master_section.{n}`.", pop, "Not produced.", "aggregate")
    passthrough = {"period", "period_date", "unit_id", "state", "control", "level", "size", "sector", "institution_name", "institution_type", "enrollment_2024", "distance_enrollment_2024"}
    modes = {"school", "department", "course_number", "course_title", "course_level", "course_subject"}
    if n in passthrough:
        return _metadata(column, f"`ANY_VALUE(master_section.{n})` within the course-term.", pop, "No section has a nonmissing value.", "aggregate")
    if n in modes:
        return _metadata(column, f"`mode(master_section.{n})` within the course-term.", pop, "No section has a nonmissing value.", "aggregate")
    expressions = {
        "section_count": "COUNT(DISTINCT section_id)", "enrollment_total": "SUM(enrollments)",
        "seats_taken_total": "SUM(seats_taken)", "total_materials": "SUM(material_count)",
        "total_required": "SUM(required_count)", "total_optional": "SUM(optional_count)",
        "is_oer": "COALESCE(BOOL_OR(is_oer), FALSE)", "is_ia": "COALESCE(BOOL_OR(is_ia), FALSE)",
        "oer_count": "SUM(oer_count)", "ia_count": "SUM(ia_count)",
        "has_isbn": "COALESCE(BOOL_OR(has_isbn), FALSE)", "has_formattype": "COALESCE(BOOL_OR(has_formattype), FALSE)",
        "isbn_count": "SUM(isbn_count)", "classified_count": "SUM(classified_count)",
        "has_enrollment_sections": "COUNT(*) FILTER (WHERE has_enrollment)",
        "has_enrollment_sibling_sections": "COUNT(*) FILTER (WHERE has_enrollment_sibling)",
        "has_enrollment_own_seats_sections": "COUNT(*) FILTER (WHERE has_enrollment_own_seats)",
        "has_enrollment_sibling_seats_sections": "COUNT(*) FILTER (WHERE has_enrollment_sibling_seats)",
        "all_publishers": "LIST(publishers) FILTER (WHERE publishers IS NOT NULL)",
        "unique_required_publishers": "SUM(required_publisher_count); sum of per-section distinct counts, not course-wide distinct publishers",
    }
    if n in expressions:
        null = "No contributing nonmissing values." if n in {"enrollment_total", "seats_taken_total", "all_publishers"} else "Never NULL for a retained group."
        return _metadata(column, f"`{expressions[n]}` over master-section rows.", pop, null, "aggregate")
    cost = re.fullmatch(r"(required|optional)_cost_(total|owned)_(min|max|avg)", n)
    if cost:
        status, scope, agg = cost.groups()
        sqlagg = {"min": "MIN", "max": "MAX", "avg": "AVG"}[agg]
        base = n if agg != "avg" else f"{status}_cost_{scope}_midpoint"
        return _metadata(column, f"{sqlagg} of section-level `{base}`; averages use section midpoints.", pop,
                         "No contributing section has the required price bound(s).", "aggregate")
    if n in {"required_cost_avg", "required_cost_owned_avg", "optional_cost_avg"}:
        bounds = {
            "required_cost_avg": "required_cost_total_min + required_cost_total_max",
            "required_cost_owned_avg": "required_cost_owned_min + required_cost_owned_max",
            "optional_cost_avg": "optional_cost_total_min + optional_cost_total_max",
        }[n]
        return _metadata(column, f"`AVG(({bounds}) / 2.0)` across section rows; mean of legacy section midpoints.", pop,
                         "No contributing section has both required bounds.", "aggregate")
    return None


def _master_course_material_metadata(column: Column) -> FieldMetadata | None:
    n = column.name
    pop = "Canonical Use items for one (course_id, period_sortable, period, period_date, school, department, course_number, course_title, publisher, book_status) group."
    group_keys = {"course_id", "period_sortable", "period", "period_date", "school", "department", "course_number", "course_title", "publisher", "book_status"}
    if n in group_keys:
        filtered = n in {"course_id", "publisher", "period_sortable"}
        source = f"Group key from `material_costs.{n}`."
        if filtered:
            source += f" SQL filters `{n} IS NOT NULL` before grouping."
            null = f"Not produced; SQL excludes rows where `{n}` is NULL before GROUP BY."
        else:
            source += " SQL groups missing source values together."
            null = "May be NULL when the source descriptor is missing; SQL groups NULL values together."
        return _metadata(column, source, pop, null, "aggregate")
    rules = {"material_instances": "COUNT(*)", "sections_using": "COUNT(DISTINCT section_id)", "total_seats_affected": "SUM(seats_taken)"}
    if n in rules:
        null = "No contributing nonmissing seats value." if n == "total_seats_affected" else "Never NULL for a retained group."
        return _metadata(column, f"`{rules[n]}` over grouped material items.", pop, null, "aggregate")
    return None


def _master_institution_metadata(column: Column) -> FieldMetadata | None:
    n = column.name
    pop = "Material-bearing master-section rows for one `(period_sortable, unit_id)` bucket, including NULL unit_id."
    if n in {"period_sortable", "unit_id"}:
        return _metadata(column, f"Institution-rollup group key from `master_section.{n}`.", pop,
                         "`unit_id` is NULL for the explicit unmatched-institution bucket; period is required.", "aggregate")
    if n in {"state", "control", "level", "size", "institution_name", "institution_type", "enrollment_2024", "distance_enrollment_2024"}:
        return _metadata(column, f"`ANY_VALUE(master_section.{n})`; IPEDS attributes are institution-grain.", pop,
                         "No matching IPEDS/source institution value.", "aggregate")
    if n == "bookstore_url":
        return _metadata(column, "Most frequent nonblank `pricing_wide.bookstore_url` for the same term×institution; lexical tie-break.",
                         "All same-term pricing rows for the institution, not only canonical Use items.",
                         "No nonblank pricing URL, or unit_id is NULL.", "joined")
    level_counts = {
        "advanced_graduate_section_count": "Advanced graduate",
        "advanced_graduate_directed_study_and_research_section_count": "Advanced graduate/ directed study and research",
        "advanced_undergraduate_section_count": "Advanced undergraduate",
        "advanced_undergraduate_graduate_section_count": "Advanced undergraduate/ graduate",
        "general_graduate_section_count": "General graduate",
        "intermediate_undergraduate_section_count": "Intermediate undergraduate",
        "introductory_or_general_undergraduate_section_count": "Introductory or general undergraduate",
        "non_degree_credit_section_count": "Non-degree credit",
        "uncategorized_section_count": "Uncategorized",
    }
    if n in level_counts:
        return _metadata(column, f"`COUNT(*) FILTER (WHERE course_level = '{level_counts[n]}')`.", pop,
                         "Never NULL; zero means no section in this exact course-level category.", "aggregate")
    predicates = {
        "section_count": "all material-bearing sections", "course_count": "distinct `course_id` values",
        "material_section_count": "`material_count > 0`", "required_section_count": "supply-aware raw `section_book_status.has_required`",
        "inferred_required_section_count": "`required_count > 0`", "optional_section_count": "`optional_count > 0`",
        "supply_section_count": "`supply_count > 0` sidecar evidence", "oer_section_count": "`oer_count > 0`",
        "ia_section_count": "`ia_count > 0`", "required_priced_section_count": "`required_priced_count > 0`",
        "optional_priced_section_count": "`optional_priced_count > 0`", "isbn_section_count": "`isbn_count > 0`",
        "enrollment_section_count": "`enrollment_assigned IS NOT NULL`", "seats_taken_section_count": "`seats_taken IS NOT NULL AND seats_taken < 9999`",
    }
    if n in predicates:
        if n == "course_count":
            expression = "`COUNT(DISTINCT course_id)` across material-bearing sections."
        elif n == "section_count":
            expression = "`COUNT(*)` across material-bearing sections."
        else:
            expression = f"`COUNT(*) FILTER` over sections satisfying {predicates[n]}."
        return _metadata(column, expression, pop,
                         "Never NULL; zero means no qualifying section/course.", "aggregate")
    if n == "enrollments_tot":
        return _metadata(column, "`SUM(enrollment_assigned)` across sections with assigned enrollment.", pop,
                         "No section has assigned enrollment.", "aggregate")
    if n == "seats_taken_tot":
        return _metadata(column, "`SUM(seats_taken) FILTER (WHERE seats_taken IS NOT NULL AND seats_taken < 9999)`.", pop,
                         "No section has valid reported seats; sentinel 9999 is excluded.", "aggregate")
    return None


def _master_isbn_metadata(column: Column) -> FieldMetadata | None:
    n = column.name
    pop = "Canonical Use `material_costs` rows for one term×non-NULL ISBN."
    if n in {"period_sortable", "isbn13"}:
        return _metadata(column, f"Group key from `material_costs.{n}`.", pop, "Not produced.", "aggregate")
    if n in {"book_title", "author", "publisher"}:
        src = "isbn_book_title" if n == "book_title" else f"isbn_{n}"
        return _metadata(column, f"`ANY_VALUE(material_costs.{src})`; term×ISBN metadata is canonical upstream.", pop,
                         "No nonmissing canonical ISBN metadata.", "aggregate")
    if n in {"title_variant_count", "author_variant_count", "publisher_variant_count"}:
        src = f"isbn_{n}"
        return _metadata(column, f"`ANY_VALUE(material_costs.{src})`.", pop, "Not expected; upstream count is non-NULL.", "aggregate")
    if n in {"is_oer", "is_ia"}:
        return _metadata(column, f"`COALESCE(BOOL_OR(material_costs.{n}), FALSE)`.", pop,
                         "Never NULL; false means no canonical ISBN row has the classification.", "aggregate")
    if n == "is_supply":
        return _metadata(column, "Constant FALSE: supplies are excluded from the canonical Use population.", pop, "Never NULL.", "derived")
    counts = {"unit_id_count": "unit_id", "section_id_count": "section_id", "course_id_count": "course_id"}
    if n in counts:
        return _metadata(column, f"`COUNT(DISTINCT {counts[n]})`.", pop,
                         "Never NULL; zero means all values of that key are missing.", "aggregate")
    if n == "has_enrollment":
        return _metadata(column, "`COALESCE(BOOL_OR(enrollment_assigned IS NOT NULL), FALSE)`.", pop,
                         "Never NULL; false means no occurrence has assigned enrollment.", "aggregate")
    if n == "enroll_cnt":
        return _metadata(column, "`COUNT(DISTINCT section_id) FILTER (WHERE enrollment_assigned IS NOT NULL)`.",
                         "Distinct ISBN-using sections.", "Never NULL; zero means none has assigned enrollment.", "aggregate")
    if n == "enroll_tot":
        return _metadata(column, "`COALESCE(SUM(enrollment_assigned), 0)` across ISBN occurrences.", pop,
                         "Never NULL; zero means no assigned enrollment or assigned total zero.", "aggregate")
    if n == "metadata_conflict":
        return _metadata(column, "True when any title/author/publisher variant count exceeds one.", pop,
                         "Never NULL; false means no detected canonical metadata conflict.", "dq")
    price = re.fullmatch(r"(price_(?:buy|rental)_(?:new|used|na)_(?:physical|digital|na))_count", n)
    if price:
        return _metadata(column, f"`COUNT(DISTINCT section_id) FILTER (WHERE {price.group(1)} IS NOT NULL)`.",
                         "Distinct ISBN-using sections in the term.", "Never NULL; zero means no section has that price cell.", "aggregate")
    institution_type_literals = {
        "institution_type_2_year_private_profit_count": "2 Year Priavte Profit",
        "institution_type_2_year_private_count": "2 Year Private",
        "institution_type_2_year_public_count": "2 Year Public",
        "institution_type_4_year_private_profit_count": "4 Year Priavte Profit",
        "institution_type_4_year_private_count": "4 Year Private",
        "institution_type_4_year_public_count": "4 Year Public",
        "institution_type_under_2_year_public_count": "Under 2 Year Public",
    }
    if n in institution_type_literals or n == "institution_type_unknown_count":
        predicate = (
            "institution_type is NULL or blank"
            if n == "institution_type_unknown_count"
            else f"institution_type = `{institution_type_literals[n]}` (exact source literal, including source spelling)"
        )
        return _metadata(column, f"`COUNT(DISTINCT section_id)` FILTERed where {predicate}.",
                         "Distinct ISBN-using sections in the term.", "Never NULL; zero means no qualifying section.", "aggregate")
    return None


def _dq_metadata(relation: str, column: Column) -> FieldMetadata | None:
    n = column.name
    if relation == "__data_quality_metrics":
        source = {
            "category": "Literal metric family emitted by `2d_data_quality.sql`.",
            "check_id": "Literal executable check identifier emitted by `2d_data_quality.sql`.",
            "metric_name": "Literal scalar measure name emitted by `2d_data_quality.sql`.",
            "metric_value": "BIGINT scalar computed by the named check; scope varies by category/check_id and is preserved by those keys.",
        }.get(n)
        if source:
            return _metadata(column, source, "One row per emitted category×check×metric in the current pipeline snapshot.",
                             "Metric keys are not NULL; metric_value can be NULL only when its SQL aggregate has no contributing rows.", "dq")
    specs: dict[str, dict[str, str]] = {
        "__data_quality_top_unmatched_ipeds_schools": {
            "school": "Catalog school group key", "unit_id": "Catalog institution-ID group key", "catalog_rows": "COUNT(*) of unmatched rows",
        },
        "__data_quality_null_isbn_breakdown": {
            "school": "Catalog school group key", "no_book_details": "COUNT where Title is `*No Book Details*`",
            "no_books_required": "COUNT where Title is `*No Books Required*`", "bad_course": "COUNT where Title is `*Bad Course*`",
            "other": "COUNT where Title is NULL or outside the three known markers", "total_null_isbn": "COUNT(*) of NULL-ISBN rows",
        },
        "__data_quality_top_null_isbn_schools": {
            "school": "Catalog school group key", "null_isbn_rows": "COUNT where ISBN13 is NULL",
            "non_null_isbn_rows": "COUNT where ISBN13 is non-NULL", "total_rows": "COUNT(*)",
            "null_pct": "100 × NULL-ISBN row count / total row count", "distinct_sections": "COUNT(DISTINCT section_id) among NULL-ISBN rows",
        },
        "__data_quality_pricing_match_by_period": {
            "period_sortable": "Pricing-period group key", "pricing_rows": "COUNT(*) of final pricing rows",
            "rows_matched": "SUM of pricing rows with exact catalog `(section_id,isbn13)` match", "match_pct": "100 × rows_matched / pricing_rows",
        },
        "__data_quality_top_unmatched_pricing_sections": {
            "unit_id": "Pricing institution group key", "period_sortable": "Pricing-period group key",
            "pricing_sections": "COUNT(*) of distinct pricing sections in the cohort", "unmatched": "COUNT where exact catalog section is absent",
            "unmatched_pct": "100 × unmatched / pricing_sections",
        },
        "__data_quality_format_count_distribution": {
            "format_count": "`pricing_wide.format_count` distribution key", "pricing_wide_rows": "COUNT(*) of wide-pricing rows in the bucket",
        },
    }
    relation_specs = specs.get(relation)
    if relation_specs and n in relation_specs:
        scope = {
            "__data_quality_top_unmatched_ipeds_schools": "Required-inferred catalog rows with no IPEDS institution; top 10 schools.",
            "__data_quality_null_isbn_breakdown": "Required-inferred catalog rows with NULL ISBN; top 20 schools.",
            "__data_quality_top_null_isbn_schools": "Required-inferred catalog rows; top 10 schools having NULL ISBN rows.",
            "__data_quality_pricing_match_by_period": "All final `pricing_historical` rows, grouped by pricing period.",
            "__data_quality_top_unmatched_pricing_sections": "All distinct final pricing sections with at least one unmatched section; top cohorts by institution×period.",
            "__data_quality_format_count_distribution": "All `pricing_wide` rows grouped by offered-tuple count.",
        }[relation]
        null = "Group key can be NULL when the source dimension is missing; computed measures are non-NULL." if n in {"school", "unit_id", "period_sortable"} else "Never NULL for an emitted diagnostic row."
        return _metadata(column, relation_specs[n] + " in `2d_data_quality.sql`.", scope, null, "dq")
    return None


def _cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def _upstream(metadata: RelationMetadata) -> str:
    return ", ".join(f"`{source}`" for source in metadata.upstream)


def _embedded_appendix(appendix_body: str) -> str:
    cleaned = appendix_body.strip()
    if cleaned.startswith("---"):
        raise ValueError("Master Section appendix must not contain frontmatter")
    lines = cleaned.splitlines()
    if lines and lines[0] == "# Master Section release dictionary":
        lines = lines[1:]
        if lines and not lines[0]:
            lines = lines[1:]
    # The standalone appendix's H2/H3 hierarchy nests one level deeper here.
    return "\n".join(
        f"#{line}" if re.match(r"^#{2,5}\s", line) else line for line in lines
    )


def render_dictionary(relations: list[Relation], appendix_body: str) -> str:
    relation_names = {relation.name for relation in relations}
    registry_names = set(RELATION_METADATA)
    if relation_names != registry_names:
        missing = sorted(relation_names - registry_names)
        extra = sorted(registry_names - relation_names)
        raise ValueError(f"relation metadata mismatch; missing={missing}, extra={extra}")
    field_metadata = resolve_field_metadata(relations, appendix_body)

    lines = [
        "---",
        f"notion-id: {NOTION_ID}",
        f"notion-url: {NOTION_URL}",
        "notion-sync: push",
        "---",
        "",
        "# CommodoreSQL data dictionary",
        "",
        "This generated dictionary describes every relation and relation column declared in the",
        "canonical `schema.dbml`. It intentionally does not query the live database. Field-level",
        "source, format, population, and NULL contracts are resolved deterministically from SQL-aligned",
        "rules, DBML notes, and the maintained Master Section appendix. Regenerate it with",
        "`python3 scripts/generate_data_dictionary.py`.",
        "",
        "View columns are included, including complete inherited schemas and field metadata for true",
        "`SELECT *` projections. Inherited rows also identify the view filter that changes population.",
        "",
        "## Source ownership and compatibility naming",
        "",
        "BMG owns course-materials and raw pricing/cost observations; BVA owns opt-out and",
        "mailing-history inputs; IPEDS owns institution metadata. Existing executable source-table",
        "names are compatibility names rather than source-prefixed names. Derived outputs omit",
        "source acronyms.",
        "",
        "## Non-Master enrichment NULL semantics",
        "",
        "- Nullable IPEDS descriptors mean no matching institution metadata was available.",
        "- A NULL panel response year means no recorded response year was available from the BVA",
        "  panel input. `is_opted_out=FALSE` is the executable default when no cleaned email matches",
        "  the BVA opt-out input; the opt-out flag itself is not nullable.",
        "- Nullable pricing fields after a LEFT join mean no exact matched value or no valid price;",
        "  `has_pricing_match` separates an unmatched row from a matched row with NULL price cells.",
        "- `current_mailing_other` is the complete residual after normalized CA, TX, FL, NY, PA,",
        "  and CAN routing, including NULL, blank, and unknown state values.",
        "",
        "## Relation index",
        "",
        "| Relation | Kind | Pipeline stage | Grain | Upstream | Intended use | Schema |",
        "|---|---|---|---|---|---|---|",
    ]
    for relation in relations:
        metadata = RELATION_METADATA[relation.name]
        schema = f"{len(relation.columns)} declared columns; detailed below"
        if relation.kind == "view" and metadata.view_schema:
            schema += f". {metadata.view_schema}"
        lines.append(
            "| "
            + " | ".join(
                _cell(value)
                for value in (
                    f"`{relation.name}`",
                    relation.kind,
                    metadata.stage,
                    metadata.grain,
                    _upstream(metadata),
                    metadata.intended_use,
                    schema or "Declared projection",
                )
            )
            + " |"
        )

    lines.extend(["", "## Relation columns", ""])
    for relation in relations:
        metadata = RELATION_METADATA[relation.name]
        lines.extend(
            [
                f"### `{relation.name}`",
                "",
                f"- Kind: {relation.kind}",
                f"- Stage: {_cell(metadata.stage)}",
                f"- Grain: {_cell(metadata.grain)}",
                f"- Upstream: {_upstream(metadata)}",
                f"- Intended use: {_cell(metadata.intended_use)}",
            ]
        )
        if relation.kind == "view":
            lines.append(
                f"- Projection: {_cell(metadata.view_schema or 'Declared SQL view projection')}"
            )
        relation_note = RELATION_NOTE_OVERRIDES.get(relation.name, relation.note)
        if relation_note:
            lines.append(f"- DBML relation note: {_cell(relation_note)}")
        lines.extend(
            [
                "",
                "| Column name | Data type | Source / derivation | Values / format | Population / denominator | NULL meaning |",
                "|---|---|---|---|---|---|",
            ]
        )
        for column in relation.columns:
            contract = field_metadata[(relation.name, column.name)]
            lines.append(
                "| "
                + " | ".join(
                    (
                        f"`{_cell(column.name)}`",
                        f"`{_cell(column.data_type)}`",
                        _cell(contract.source),
                        _cell(contract.values),
                        _cell(contract.population),
                        _cell(contract.null_meaning),
                    )
                )
                + " |"
        )
        lines.append("")

    lines.extend(
        [
            "## Detailed Master Section appendix",
            "",
            "The following repo-level contract is embedded from `MASTER-SECTION-DICTIONARY.md`",
            "so the synced Notion Data Dictionary remains self-contained.",
            "",
            _embedded_appendix(appendix_body),
            "",
        ]
    )
    return "\n".join(lines)


def generate(schema_path: Path, appendix_path: Path) -> str:
    return render_dictionary(
        parse_dbml(schema_path), appendix_path.read_text(encoding="utf-8")
    )


def main(argv: list[str] | None = None) -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", type=Path, default=repo_root / "schema.dbml")
    parser.add_argument(
        "--appendix", type=Path, default=repo_root / "MASTER-SECTION-DICTIONARY.md"
    )
    parser.add_argument("--output", type=Path, default=repo_root / "DATA-DICTIONARY.md")
    parser.add_argument(
        "--check", action="store_true", help="fail if the checked-in output is stale"
    )
    args = parser.parse_args(argv)
    rendered = generate(args.schema, args.appendix)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != rendered:
            print(f"stale generated file: {args.output}", file=sys.stderr)
            return 1
        return 0
    args.output.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
