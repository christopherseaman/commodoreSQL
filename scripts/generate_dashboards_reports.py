#!/usr/bin/env python3
"""Render the repository's Metabase dashboard/card/model inventory."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
METABASE_URL = "https://meta.badmath.org"
EXPECTED = {
    "dashboards": 14,
    "questions": 72,
    "models": 4,
    "placements": 79,
    "dashboard_used": 61,
    "standalone": 11,
}

MAX_RENDERED_LINES = 450
MAX_RENDERED_WORDS = 2_700

GROUPS = [
    (
        "Reporting & analytical surfaces",
        [
            "report.json",
            "course_materials_cost.json",
            "oer_ia_adoption.json",
        ],
    ),
    (
        "BMG Fall 2025 analysis",
        [
            "bmg_overview.json",
            "bmg_enrollment_dq.json",
            "bmg_cost_hypothesis.json",
        ],
    ),
    (
        "Coverage & lineage",
        ["data_coverage.json", "bmg_coverage_scope.json", "data_lineage.json"],
    ),
    (
        "Data quality dashboards",
        [
            "filter_include_quality.json",
            "oer_ia_status_filtered.json",
            "data_quality_catalog.json",
            "data_quality_pricing.json",
            "data_quality_pricing_filtered.json",
        ],
    ),
]

STANDALONE_GROUPS = [
    (
        "Fall 2025 extracts and operational audits",
        [
            "35_sections_ca_public_fall2025",
            "46_master_isbn_fall2025",
            "58_top100_nonsupply_missing_formattype",
            "63_no_price_choice_by_class",
            "64_fall2025_unitid_bookstore_url_mapping",
            "73_fall2025_pricing_catalog_populations",
            "74_fall2025_pricing_catalog_examples",
        ],
    ),
    (
        "Same-item pricing analyses",
        [
            "59_sameisbn_price_by_required_status",
            "60_sameisbn_price_by_book_status",
        ],
    ),
    (
        "ISBN identity and title-cluster review",
        [
            "61_master_isbn_variability",
            "62_master_isbn_title_cluster_candidates",
        ],
    ),
]

def metadata(path: Path) -> tuple[str, str]:
    name = description = ""
    for line in path.read_text(encoding="utf-8").splitlines()[:20]:
        if line.startswith("-- name:"):
            name = line.removeprefix("-- name:").strip()
        elif line.startswith("-- description:"):
            description = line.removeprefix("-- description:").strip()
    if not name:
        raise ValueError(f"missing SQL frontmatter name: {path}")
    return name, description


def load() -> tuple[dict, list[dict], dict[str, tuple[str, str]], dict[str, tuple[str, str]]]:
    ids = json.loads((ROOT / "metabase/ids.json").read_text(encoding="utf-8"))
    dashboards: list[dict] = []
    used: list[str] = []
    for path in sorted((ROOT / "metabase/dashboards").glob("*.json")):
        entries = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(entries, list) or not entries or "__meta__" not in entries[0]:
            raise ValueError(f"unexpected dashboard format: {path}")
        meta = entries[0]["__meta__"]
        cards = [entry["question"] for entry in entries[1:] if "question" in entry]
        dashboards.append({"path": path, "meta": meta, "cards": cards})
        used.extend(cards)

    questions: dict[str, tuple[str, str]] = {}
    for path in sorted((ROOT / "metabase/questions").glob("*.sql")):
        questions[path.stem] = metadata(path)
    models: dict[str, tuple[str, str]] = {}
    for path in sorted((ROOT / "metabase/models").glob("*.sql")):
        models["model_" + path.stem] = metadata(path)

    expected_used = set(used)
    if len(dashboards) != EXPECTED["dashboards"]:
        raise ValueError("dashboard count mismatch")
    if len(questions) != EXPECTED["questions"]:
        raise ValueError("question count mismatch")
    if len(models) != EXPECTED["models"]:
        raise ValueError("model count mismatch")
    if len(used) != EXPECTED["placements"]:
        raise ValueError("dashboard placement count mismatch")
    if len(expected_used) != EXPECTED["dashboard_used"]:
        raise ValueError("unique dashboard-used question count mismatch")
    if len(set(questions) - expected_used) != EXPECTED["standalone"]:
        raise ValueError("standalone question count mismatch")
    for dashboard in dashboards:
        stem = "dashboard_" + dashboard["path"].stem
        if stem not in ids:
            raise ValueError(f"missing dashboard ID: {stem}")
        for card in dashboard["cards"]:
            if card not in ids or card not in questions:
                raise ValueError(f"missing card ID or SQL metadata: {card}")
    for key in questions | models:
        if key not in ids:
            raise ValueError(f"missing ID: {key}")
    configured_dashboards = [filename for _, filenames in GROUPS for filename in filenames]
    discovered_dashboards = {dashboard["path"].name for dashboard in dashboards}
    if len(configured_dashboards) != len(set(configured_dashboards)):
        raise ValueError("duplicate dashboard filename in conceptual groups")
    if set(configured_dashboards) != discovered_dashboards:
        raise ValueError("conceptual dashboard filenames do not match discovered dashboards")
    configured_standalone = [stem for _, stems in STANDALONE_GROUPS for stem in stems]
    computed_standalone = set(questions) - expected_used
    if len(configured_standalone) != len(set(configured_standalone)):
        raise ValueError("duplicate standalone question stem in conceptual groups")
    if set(configured_standalone) != computed_standalone:
        raise ValueError("conceptual standalone stems do not match computed standalone questions")
    return ids, dashboards, questions, models


def clean(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def table_cell(text: str) -> str:
    return clean(text).replace("|", "\\|")


def scope_label(description: str) -> str:
    """Use the concise first sentence from authoritative metadata."""
    normalized = clean(description)
    sentences = re.split(r"(?<=[.!?])\s+(?=[A-Z])", normalized)
    if re.fullmatch(r"(?:Issue|BMG task) #\d+\.", sentences[0]) and len(sentences) > 1:
        return sentences[1]
    return sentences[0]


def card_row(stem: str, ids: dict, questions: dict[str, tuple[str, str]]) -> str:
    title, description = questions[stem]
    card_id = ids[stem]
    return " | ".join(
        (
            f"| [{table_cell(title)}]({METABASE_URL}/question/{card_id})",
            f"[`{card_id}`](metabase/questions/{stem}.sql)",
            f"{table_cell(scope_label(description))} |",
        )
    )


def validate_rendered(rendered: str) -> None:
    lines = rendered.splitlines()
    words = rendered.split()
    expected_question_rows = EXPECTED["placements"] + EXPECTED["standalone"]
    checks = {
        "legacy card blocks remain": "\n#### " not in rendered,
        "dashboard card table count mismatch": rendered.count("| Card | ID | Scope |")
        == EXPECTED["dashboards"] + len(STANDALONE_GROUPS),
        "model table count mismatch": rendered.count("| Model | ID | Scope |") == 1,
        "question repository-link count mismatch": rendered.count("](metabase/questions/") == expected_question_rows,
        "question destination-link count mismatch": rendered.count(f"]({METABASE_URL}/question/") == expected_question_rows,
        "dashboard source count mismatch": rendered.count("](metabase/dashboards/") == EXPECTED["dashboards"],
        "dashboard destination-link count mismatch": rendered.count(f"]({METABASE_URL}/dashboard/") == EXPECTED["dashboards"],
        "model row count mismatch": rendered.count("](metabase/models/") == EXPECTED["models"],
        "model destination-link count mismatch": rendered.count(f"]({METABASE_URL}/model/") == EXPECTED["models"],
        f"rendered line budget exceeds {MAX_RENDERED_LINES}": len(lines) <= MAX_RENDERED_LINES,
        f"rendered word budget exceeds {MAX_RENDERED_WORDS}": len(words) <= MAX_RENDERED_WORDS,
    }
    for error, passed in checks.items():
        if not passed:
            raise ValueError(error)


def render() -> str:
    ids, dashboards, questions, models = load()
    by_file = {dashboard["path"].name: dashboard for dashboard in dashboards}
    lines = [
        "---",
        "notion-id: 3cbd9fdd-1a1a-80ee-884d-f4c7003aaf44",
        "notion-url: https://app.notion.com/p/sqrlly/Dashboards-Reports-3cbd9fdd1a1a80ee884df4c7003aaf44",
        "notion-sync: push",
        "---",
        "",
        "# Dashboards & Reports",
        "",
        "",
    ]
    for group, files in GROUPS:
        lines += [f"## {group}", ""]
        for filename in files:
            dashboard = by_file[filename]
            path = dashboard["path"]
            meta = dashboard["meta"]
            key = "dashboard_" + path.stem
            lines += [
                f"### [{meta['name']}]({METABASE_URL}/dashboard/{ids[key]})",
                "",
                f"ID `{ids[key]}` · [repository definition](metabase/dashboards/{path.name}) · {scope_label(meta.get('description', ''))}",
                "",
                "| Card | ID | Scope |",
                "|---|---:|---|",
            ]
            for stem in dashboard["cards"]:
                lines.append(card_row(stem, ids, questions))
            lines.append("")
    lines += ["## Standalone cards", ""]
    for group, stems in STANDALONE_GROUPS:
        lines += [
            f"### {group}",
            "",
            "| Card | ID | Scope |",
            "|---|---:|---|",
        ]
        for stem in stems:
            lines.append(card_row(stem, ids, questions))
        lines.append("")
    lines += [
        "## Models",
        "",
        "| Model | ID | Scope |",
        "|---|---:|---|",
    ]
    for key in ("model_master_institution", "model_master_isbn", "model_master_section", "model_sample_section_us_intro_fall2025"):
        title, description = models[key]
        stem = key.removeprefix("model_")
        model_id = ids[key]
        lines.append(
            " | ".join(
                (
                    f"| [{table_cell(title)}]({METABASE_URL}/model/{model_id})",
                    f"[`{model_id}`](metabase/models/{stem}.sql)",
                    f"{table_cell(scope_label(description))} |",
                )
            )
        )
    lines += [
        "",
        "## Coverage checks",
        "",
        f"- Dashboards: {EXPECTED['dashboards']}; questions: {EXPECTED['questions']}; models: {EXPECTED['models']}",
        f"- Placements: {EXPECTED['placements']}; dashboard-used questions: {EXPECTED['dashboard_used']}; standalone: {EXPECTED['standalone']}",
        "",
        "## Regeneration",
        "",
        "Regenerate: `python3 scripts/generate_dashboards_reports.py`; verify: `--check`.",
        "",
    ]
    rendered = "\n".join(lines)
    validate_rendered(rendered)
    return rendered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="compare generated Markdown with DASHBOARDS-REPORTS.md")
    args = parser.parse_args()
    rendered = render()
    if args.check:
        target = ROOT / "DASHBOARDS-REPORTS.md"
        actual = target.read_text(encoding="utf-8") if target.exists() else ""
        if actual != rendered:
            print(f"{target} is out of date", file=sys.stderr)
            return 1
        print("DASHBOARDS-REPORTS.md is up to date")
        return 0
    sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
