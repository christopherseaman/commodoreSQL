#!/usr/bin/env python3
"""
Sync SQL question files and dashboard definitions to Metabase via API.

QUESTIONS  metabase/questions/*.sql with comment-line frontmatter:
  -- name: My Question Title
  -- display: table        (table, bar, line, pie, scalar — default: table)
  -- description: optional
  -- collection_id: 7      (default: 7 = BMG collection)

  Optional filter parameters via a metabase/questions/<stem>.params.json sidecar.
  Each key is a template-tag name that must appear in the SQL as {{name}} (use
  Metabase optional syntax `[[ AND {{name}} ]]`):
    {
      "state":   { "display-name": "State",  "field": "comprehensive_data.state" },
      "control": { "display-name": "Control", "field": "comprehensive_data.control",
                   "widget-type": "string/=" }
    }
  "field" = "table.column" makes a field filter (dropdown); omit it for a raw
  {{variable}} (set "type": "text"|"number"|"date").

DASHBOARDS  metabase/dashboards/*.json — array of card layouts:
  [
    { "__meta__": { "name": "...", "description": "...",
                    "parameters": [ { "name": "State", "slug": "state" },
                                    { "name": "Control", "slug": "control" } ] } },
    { "question": "30_report_overview", "row": 0, "col": 0, "size_x": 24, "size_y": 8 }
  ]
  Each dashboard parameter is auto-mapped to every card whose .params.json declares
  a template-tag with the same name as the parameter slug.

IDs are tracked in metabase/ids.json so re-runs update rather than duplicate.

Usage:
  python metabase/sync.py             # sync all questions and dashboards
  python metabase/sync.py --dry-run   # preview without making changes
  python metabase/sync.py --list      # list synced items and their IDs
"""

import hashlib
import json
import os
import sys
import urllib.request
import urllib.error
import uuid
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
QUESTIONS_DIR = SCRIPT_DIR / "questions"
DASHBOARDS_DIR = SCRIPT_DIR / "dashboards"
IDS_FILE = SCRIPT_DIR / "ids.json"

METABASE_URL = os.environ.get("METABASE_URL", "http://localhost:3000").rstrip("/")
API_KEY = os.environ.get("METABASE_API_KEY", "")
DB_ID = int(os.environ.get("METABASE_DB_ID", "2"))
DEFAULT_COLLECTION_ID = 7  # BMG


# ---------------------------------------------------------------------------
# API helpers
# ---------------------------------------------------------------------------

def api(method, path, body=None):
    url = f"{METABASE_URL}/api{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"X-API-Key": API_KEY, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        body_text = e.read().decode()
        print(f"  HTTP {e.code} {method} {path}: {body_text[:200]}", file=sys.stderr)
        raise


def card_exists(card_id: int) -> bool:
    try:
        api("GET", f"/card/{card_id}")
        return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise


def dashboard_exists(dash_id: int) -> bool:
    try:
        api("GET", f"/dashboard/{dash_id}")
        return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise


# ---------------------------------------------------------------------------
# Filter parameters (template-tags + field-id resolution)
# ---------------------------------------------------------------------------

_FIELD_INDEX = None


def field_index() -> dict:
    """{(table_name, column_name): field_id} from the DB metadata (fetched once)."""
    global _FIELD_INDEX
    if _FIELD_INDEX is None:
        meta = api("GET", f"/database/{DB_ID}/metadata")
        _FIELD_INDEX = {}
        for t in meta.get("tables", []):
            for f in t.get("fields", []):
                _FIELD_INDEX[(t["name"], f["name"])] = f["id"]
    return _FIELD_INDEX


def _stable_uuid(seed: str) -> str:
    return str(uuid.UUID(hashlib.md5(seed.encode()).hexdigest()))


def _stable_param_id(slug: str) -> str:
    return hashlib.md5(slug.encode()).hexdigest()[:8]


def load_params(sql_path: Path) -> dict:
    """Load optional filter-parameter declarations from a <stem>.params.json sidecar."""
    p = sql_path.with_suffix(".params.json")
    return json.loads(p.read_text()) if p.exists() else {}


def build_template_tags(stem: str, params: dict) -> dict:
    """Turn a .params.json spec into Metabase native template-tags (resolving field ids)."""
    fi = field_index()
    tags = {}
    for name, spec in params.items():
        tag = {
            "id": _stable_uuid(f"{stem}:{name}"),
            "name": name,
            "display-name": spec.get("display-name", name.replace("_", " ").title()),
            "default": spec.get("default"),
        }
        if "field" in spec:  # field filter (dropdown)
            tbl, _, col = spec["field"].partition(".")
            fid = fi.get((tbl, col))
            if fid is None:
                print(f"  Warning: field '{spec['field']}' not found — skipping tag {name}", file=sys.stderr)
                continue
            tag["type"] = "dimension"
            tag["dimension"] = ["field", fid, None]
            tag["widget-type"] = spec.get("widget-type", "string/=")
        else:  # raw {{variable}}
            tag["type"] = spec.get("type", "text")
        tags[name] = tag
    return tags


# ---------------------------------------------------------------------------
# Questions
# ---------------------------------------------------------------------------

def parse_question(path: Path) -> dict:
    lines = path.read_text().splitlines()
    meta = {"display": "table", "collection_id": DEFAULT_COLLECTION_ID}
    sql_lines = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("-- ") and ":" in stripped[3:]:
            key, _, value = stripped[3:].partition(":")
            meta[key.strip()] = value.strip()
        else:
            sql_lines.append(line)

    if "name" not in meta:
        meta["name"] = path.stem.replace("_", " ").title()

    meta["query"] = "\n".join(sql_lines).strip()
    return meta


def load_viz_settings(sql_path: Path) -> dict:
    """Load optional visualization settings from a .viz.json sidecar file."""
    viz_path = sql_path.with_suffix(".viz.json")
    if viz_path.exists():
        return json.loads(viz_path.read_text())
    return {}


def build_card_payload(meta: dict) -> dict:
    native = {"query": meta["query"]}
    if meta.get("template_tags"):
        native["template-tags"] = meta["template_tags"]
    payload = {
        "name": meta["name"],
        "display": meta.get("display", "table"),
        "database_id": DB_ID,
        "dataset_query": {
            "type": "native",
            "native": native,
            "database": DB_ID,
        },
        "visualization_settings": meta.get("viz_settings", {}),
        "collection_id": int(meta.get("collection_id", DEFAULT_COLLECTION_ID)),
    }
    if meta.get("description"):
        payload["description"] = meta["description"]
    return payload


def sync_question(path: Path, ids: dict, dry_run: bool) -> dict:
    meta = parse_question(path)
    meta["viz_settings"] = load_viz_settings(path)
    params = load_params(path)
    key = path.stem
    existing_id = ids.get(key)

    if dry_run:
        action = "UPDATE" if existing_id else "CREATE"
        extra = f", {len(params)} filter(s): {', '.join(params)}" if params else ""
        print(f"  [{action}] question: {meta['name']} (display={meta['display']}{extra})")
        return ids

    if params:
        meta["template_tags"] = build_template_tags(key, params)
    payload = build_card_payload(meta)

    if existing_id and card_exists(existing_id):
        api("PUT", f"/card/{existing_id}", payload)
        print(f"  updated  card {existing_id}: {meta['name']}")
    else:
        card = api("POST", "/card", payload)
        ids[key] = card["id"]
        print(f"  created  card {ids[key]}: {meta['name']}")

    return ids


# ---------------------------------------------------------------------------
# Dashboards
# ---------------------------------------------------------------------------

def parse_dashboard(path: Path) -> tuple[dict, list]:
    """Return (meta, cards) from a dashboard JSON file."""
    items = json.loads(path.read_text())

    meta = {"collection_id": DEFAULT_COLLECTION_ID}
    cards = []

    for item in items:
        if "__meta__" in item:
            meta.update(item["__meta__"])
        else:
            cards.append(item)

    if "name" not in meta:
        meta["name"] = path.stem.replace("_", " ").title()

    return meta, cards


def build_dashboard_parameters(meta: dict) -> list:
    """Dashboard-level filter params (stable ids derived from slug)."""
    out = []
    for p in meta.get("parameters", []):
        param = {
            "id": _stable_param_id(p["slug"]),
            "name": p["name"],
            "slug": p["slug"],
            "type": p.get("type", "string/="),
            "sectionId": p.get("sectionId", "string"),
        }
        if "default" in p:
            param["default"] = p["default"]
        out.append(param)
    return out


def sync_dashboard(path: Path, ids: dict, dry_run: bool) -> dict:
    meta, card_layouts = parse_dashboard(path)
    key = f"dashboard_{path.stem}"
    existing_id = ids.get(key)
    params_out = build_dashboard_parameters(meta)

    if dry_run:
        action = "UPDATE" if existing_id else "CREATE"
        pstr = f"  [{len(params_out)} filter(s): {', '.join(p['slug'] for p in params_out)}]" if params_out else ""
        print(f"  [{action}] dashboard: {meta['name']}{pstr}")
        for layout in card_layouts:
            q_key = layout["question"]
            card_id = ids.get(q_key, "?")
            print(f"    card {card_id} ({q_key})  row={layout['row']} col={layout['col']} {layout['size_x']}×{layout['size_y']}")
        return ids

    # Resolve question stems to card IDs and auto-map params to matching template-tags.
    dashcards = []
    for i, layout in enumerate(card_layouts):
        q_key = layout["question"]
        card_id = ids.get(q_key)
        if not card_id:
            print(f"  Warning: question '{q_key}' not in ids.json — skipping card", file=sys.stderr)
            continue
        card_tags = load_params(QUESTIONS_DIR / f"{q_key}.sql")
        pmaps = []
        for p in params_out:
            if p["slug"] not in card_tags:
                continue
            # field filters target a dimension; raw {{variables}} target a variable
            kind = "dimension" if "field" in card_tags[p["slug"]] else "variable"
            pmaps.append({"parameter_id": p["id"], "card_id": card_id,
                          "target": [kind, ["template-tag", p["slug"]]]})
        dashcards.append({
            "id": -(i + 1),  # negative sentinel for new dashcards; Metabase replaces on save
            "card_id": card_id,
            "row": layout["row"],
            "col": layout["col"],
            "size_x": layout["size_x"],
            "size_y": layout["size_y"],
            "series": [],
            "parameter_mappings": pmaps,
            "visualization_settings": {},
        })

    dash_body = {
        "name": meta["name"],
        "description": meta.get("description"),
        "collection_id": int(meta.get("collection_id", DEFAULT_COLLECTION_ID)),
        "parameters": params_out,
    }
    if existing_id and dashboard_exists(existing_id):
        api("PUT", f"/dashboard/{existing_id}", dash_body)
        api("PUT", f"/dashboard/{existing_id}/cards", {"cards": dashcards})
        print(f"  updated  dashboard {existing_id}: {meta['name']} ({len(dashcards)} cards, {len(params_out)} filters)")
    else:
        dash = api("POST", "/dashboard", dash_body)
        ids[key] = dash["id"]
        save_ids(ids)  # save before cards call so ID isn't lost on partial failure
        api("PUT", f"/dashboard/{ids[key]}/cards", {"cards": dashcards})
        print(f"  created  dashboard {ids[key]}: {meta['name']} ({len(dashcards)} cards, {len(params_out)} filters)")

    return ids


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def load_ids() -> dict:
    return json.loads(IDS_FILE.read_text()) if IDS_FILE.exists() else {}


def save_ids(ids: dict):
    IDS_FILE.write_text(json.dumps(ids, indent=2) + "\n")


def main():
    dry_run = "--dry-run" in sys.argv
    list_mode = "--list" in sys.argv

    if not API_KEY:
        print("Error: METABASE_API_KEY not set. Source scripts/dot.env first.", file=sys.stderr)
        sys.exit(1)

    ids = load_ids()

    if list_mode:
        questions = {k: v for k, v in ids.items() if not k.startswith("dashboard_")}
        dashboards = {k: v for k, v in ids.items() if k.startswith("dashboard_")}
        if questions:
            print("Questions:")
            for key, card_id in questions.items():
                print(f"  {key} → card {card_id}  ({METABASE_URL}/question/{card_id})")
        if dashboards:
            print("Dashboards:")
            for key, dash_id in dashboards.items():
                print(f"  {key} → dashboard {dash_id}  ({METABASE_URL}/dashboard/{dash_id})")
        if not ids:
            print("Nothing synced yet.")
        return

    sql_files = sorted(QUESTIONS_DIR.glob("*.sql"))
    dash_files = sorted(DASHBOARDS_DIR.glob("*.json")) if DASHBOARDS_DIR.exists() else []

    total = len(sql_files) + len(dash_files)
    if not total:
        print("No files found to sync.")
        return

    label = "  [dry run]" if dry_run else ""
    print(f"Syncing {len(sql_files)} question(s) and {len(dash_files)} dashboard(s) to {METABASE_URL}{label}...")

    for path in sql_files:
        ids = sync_question(path, ids, dry_run)

    for path in dash_files:
        ids = sync_dashboard(path, ids, dry_run)

    if not dry_run:
        save_ids(ids)
        print(f"IDs saved to {IDS_FILE}")


if __name__ == "__main__":
    main()
