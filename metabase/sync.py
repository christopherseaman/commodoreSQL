#!/usr/bin/env python3
"""
Sync SQL question files to Metabase via API.

Question files live in metabase/questions/*.sql with comment-line frontmatter:
  -- name: My Question Title
  -- display: table        (table, bar, line, pie, scalar — default: table)
  -- description: optional
  -- collection_id: 7      (default: 7 = BMG collection)

IDs are tracked in metabase/ids.json so re-runs update rather than duplicate.

Usage:
  python metabase/sync.py             # sync all questions
  python metabase/sync.py --dry-run   # preview without making changes
  python metabase/sync.py --list      # list synced questions and their IDs
"""

import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
QUESTIONS_DIR = SCRIPT_DIR / "questions"
IDS_FILE = SCRIPT_DIR / "ids.json"

# Load config from environment (set by sourcing scripts/dot.env)
METABASE_URL = os.environ.get("METABASE_URL", "http://localhost:3000").rstrip("/")
API_KEY = os.environ.get("METABASE_API_KEY", "")
DB_ID = int(os.environ.get("METABASE_DB_ID", "2"))
DEFAULT_COLLECTION_ID = 7  # BMG


def api(method, path, body=None):
    url = f"{METABASE_URL}/api{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "X-API-Key": API_KEY,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  HTTP {e.code} {method} {path}: {body[:200]}", file=sys.stderr)
        raise


def parse_question(path: Path) -> dict:
    """Parse a SQL file with comment-line frontmatter into a question definition."""
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


def load_ids() -> dict:
    if IDS_FILE.exists():
        return json.loads(IDS_FILE.read_text())
    return {}


def save_ids(ids: dict):
    IDS_FILE.write_text(json.dumps(ids, indent=2) + "\n")


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
        "visualization_settings": {},
        "collection_id": int(meta.get("collection_id", DEFAULT_COLLECTION_ID)),
    }
    if meta.get("description"):
        payload["description"] = meta["description"]
    return payload


def sync_question(path: Path, ids: dict, dry_run: bool) -> dict:
    meta = parse_question(path)
    key = path.stem
    existing_id = ids.get(key)

    if dry_run:
        action = "UPDATE" if existing_id else "CREATE"
        print(f"  [{action}] {meta['name']} (display={meta['display']})")
        return ids

    payload = build_card_payload(meta)

    if existing_id:
        # Verify card still exists
        try:
            api("GET", f"/card/{existing_id}")
            api("PUT", f"/card/{existing_id}", payload)
            print(f"  updated  card {existing_id}: {meta['name']}")
        except urllib.error.HTTPError:
            # Card was deleted; recreate
            card = api("POST", "/card", payload)
            ids[key] = card["id"]
            print(f"  created  card {card['id']} (was {existing_id}): {meta['name']}")
    else:
        card = api("POST", "/card", payload)
        ids[key] = card["id"]
        print(f"  created  card {card['id']}: {meta['name']}")

    return ids


def main():
    dry_run = "--dry-run" in sys.argv
    list_mode = "--list" in sys.argv

    if not API_KEY:
        print("Error: METABASE_API_KEY not set. Source scripts/dot.env first.", file=sys.stderr)
        sys.exit(1)

    ids = load_ids()

    if list_mode:
        if not ids:
            print("No questions synced yet.")
        for key, card_id in ids.items():
            print(f"  {key} → card {card_id}  ({METABASE_URL}/question/{card_id})")
        return

    sql_files = sorted(QUESTIONS_DIR.glob("*.sql"))
    if not sql_files:
        print(f"No SQL files found in {QUESTIONS_DIR}")
        return

    print(f"Syncing {len(sql_files)} question(s) to {METABASE_URL}{'  [dry run]' if dry_run else ''}...")
    for path in sql_files:
        ids = sync_question(path, ids, dry_run)

    if not dry_run:
        save_ids(ids)
        print(f"IDs saved to {IDS_FILE}")


if __name__ == "__main__":
    main()
