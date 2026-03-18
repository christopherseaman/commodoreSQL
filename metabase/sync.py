#!/usr/bin/env python3
"""
Sync SQL question files and dashboard definitions to Metabase via API.

QUESTIONS  metabase/questions/*.sql with comment-line frontmatter:
  -- name: My Question Title
  -- display: table        (table, bar, line, pie, scalar — default: table)
  -- description: optional
  -- collection_id: 7      (default: 7 = BMG collection)

DASHBOARDS  metabase/dashboards/*.json — array of card layouts:
  [
    { "question": "04_filtered_formattype_status", "row": 0, "col": 0, "size_x": 24, "size_y": 8 },
    { "question": "05_filtered_oer_over_time",     "row": 8, "col": 0, "size_x": 24, "size_y": 8 }
  ]
  The filename stem becomes the dashboard name (underscores → spaces, title-cased)
  unless a "name" key is present in the first card's metadata file
  (or put { "__meta__": { "name": "...", "description": "..." } } as first element).

IDs are tracked in metabase/ids.json so re-runs update rather than duplicate.

Usage:
  python metabase/sync.py             # sync all questions and dashboards
  python metabase/sync.py --dry-run   # preview without making changes
  python metabase/sync.py --list      # list synced items and their IDs
"""

import json
import os
import sys
import urllib.request
import urllib.error
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
    payload = {
        "name": meta["name"],
        "display": meta.get("display", "table"),
        "database_id": DB_ID,
        "dataset_query": {
            "type": "native",
            "native": {"query": meta["query"]},
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
    key = path.stem
    existing_id = ids.get(key)

    if dry_run:
        action = "UPDATE" if existing_id else "CREATE"
        print(f"  [{action}] question: {meta['name']} (display={meta['display']})")
        return ids

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


def sync_dashboard(path: Path, ids: dict, dry_run: bool) -> dict:
    meta, card_layouts = parse_dashboard(path)
    key = f"dashboard_{path.stem}"
    existing_id = ids.get(key)

    if dry_run:
        action = "UPDATE" if existing_id else "CREATE"
        print(f"  [{action}] dashboard: {meta['name']}")
        for layout in card_layouts:
            q_key = layout["question"]
            card_id = ids.get(q_key, "?")
            print(f"    card {card_id} ({q_key})  row={layout['row']} col={layout['col']} {layout['size_x']}×{layout['size_y']}")
        return ids

    # Resolve question stems to card IDs
    dashcards = []
    for i, layout in enumerate(card_layouts):
        q_key = layout["question"]
        card_id = ids.get(q_key)
        if not card_id:
            print(f"  Warning: question '{q_key}' not in ids.json — skipping card", file=sys.stderr)
            continue
        dashcards.append({
            "id": -(i + 1),  # negative sentinel for new dashcards; Metabase replaces on save
            "card_id": card_id,
            "row": layout["row"],
            "col": layout["col"],
            "size_x": layout["size_x"],
            "size_y": layout["size_y"],
            "series": [],
            "parameter_mappings": [],
            "visualization_settings": {},
        })

    if existing_id and dashboard_exists(existing_id):
        api("PUT", f"/dashboard/{existing_id}", {
            "name": meta["name"],
            "description": meta.get("description"),
            "collection_id": int(meta.get("collection_id", DEFAULT_COLLECTION_ID)),
        })
        api("PUT", f"/dashboard/{existing_id}/cards", {"cards": dashcards})
        print(f"  updated  dashboard {existing_id}: {meta['name']} ({len(dashcards)} cards)")
    else:
        dash = api("POST", "/dashboard", {
            "name": meta["name"],
            "description": meta.get("description"),
            "collection_id": int(meta.get("collection_id", DEFAULT_COLLECTION_ID)),
        })
        ids[key] = dash["id"]
        save_ids(ids)  # save before cards call so ID isn't lost on partial failure
        api("PUT", f"/dashboard/{ids[key]}/cards", {"cards": dashcards})
        print(f"  created  dashboard {ids[key]}: {meta['name']} ({len(dashcards)} cards)")

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
