#!/usr/bin/env python3
"""Safely synchronize the generated field dictionary into a Notion data source."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from shutil import which
from typing import Any


HEADERS = [
    "relation", "kind", "ordinal", "column", "type", "example / structure",
    "direct upstream source / derivation", "description", "null meaning",
]
PROPERTY_TYPES = {
    "Column": "title", "Table": "rich_text", "Type": "rich_text",
    "Direct upstream": "rich_text", "Example / format": "rich_text",
    "Description": "rich_text", "NULL meaning": "rich_text", "Order": "number",
    "Kind": "select", "Key": "rich_text",
}
STATE_VERSION = 1
DEFAULT_TSV = Path("docs/data-dictionary.tsv")
DEFAULT_STATE = Path(".notion/dictionary-state.json")
DEFAULT_CONFIG = Path("scripts/notion_dictionary.json")
TIMEOUT_SECONDS = 60
MAX_ATTEMPTS = 5
WORKERS = 3
REQUESTS_PER_SECOND = 2.0


class SyncError(Exception):
    pass


@dataclass(frozen=True)
class LocalRow:
    key: str
    values: dict[str, Any]


@dataclass(frozen=True)
class RemoteRow:
    page_id: str
    values: dict[str, Any]


class Throttle:
    def __init__(self, rate: float = REQUESTS_PER_SECOND):
        self.interval = 1.0 / rate
        self.next_at = 0.0
        self.lock = threading.Lock()

    def wait(self) -> None:
        with self.lock:
            now = time.monotonic()
            delay = max(0.0, self.next_at - now)
            self.next_at = max(now, self.next_at) + self.interval
        if delay:
            time.sleep(delay)


class NotionClient:
    def __init__(self, executable: str, *, throttle: Throttle | None = None):
        self.executable = executable
        self.throttle = throttle or Throttle()

    def request(self, path: str, method: str = "GET", body: dict[str, Any] | None = None,
                *, retry_transient: bool = True) -> dict[str, Any]:
        command = [self.executable, "api", path, "--method", method]
        request = None
        if body is not None:
            command += ["--data", "@-"]
            request = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode()
        env = os.environ.copy()
        env["NOTION_KEYRING"] = "0"
        last_detail = ""
        for attempt in range(MAX_ATTEMPTS):
            self.throttle.wait()
            try:
                result = subprocess.run(
                    command, input=request, capture_output=True, env=env,
                    timeout=TIMEOUT_SECONDS,
                )
            except subprocess.TimeoutExpired:
                last_detail = f"timed out after {TIMEOUT_SECONDS}s"
                transient = True
            else:
                if result.returncode == 0:
                    try:
                        payload = json.loads(result.stdout)
                    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                        raise SyncError(f"Notion API {method} {path} returned invalid JSON") from exc
                    if not isinstance(payload, dict):
                        raise SyncError(f"Notion API {method} {path} returned an unexpected response")
                    return payload
                last_detail = (result.stderr or result.stdout).decode("utf-8", "replace").strip()
                lowered = last_detail.lower()
                transient = any(token in lowered for token in ("429", "rate limit", "502", "503", "504", "timeout", "temporar"))
            if not retry_transient or not transient or attempt + 1 == MAX_ATTEMPTS:
                break
            time.sleep(min(2 ** attempt, 8))
        raise SyncError(f"Notion API {method} {path} failed after {attempt + 1} attempt(s): {last_detail or 'no details'}")


def rich_text(content: str) -> list[dict[str, Any]]:
    return [{"type": "text", "text": {"content": content[index:index + 2000]}}
            for index in range(0, len(content), 2000)]


def notion_properties(values: dict[str, Any]) -> dict[str, Any]:
    properties: dict[str, Any] = {}
    for name, expected_type in PROPERTY_TYPES.items():
        value = values[name]
        if expected_type == "title":
            properties[name] = {"title": rich_text(value)}
        elif expected_type == "rich_text":
            properties[name] = {"rich_text": rich_text(value)}
        elif expected_type == "number":
            properties[name] = {"number": value}
        else:
            properties[name] = {"select": {"name": value}}
    return properties


def read_text(prop: Any, field_type: str) -> str:
    if not isinstance(prop, dict) or prop.get("type") not in (None, field_type):
        raise SyncError(f"remote property has invalid {field_type} value")
    parts = prop.get(field_type)
    if not isinstance(parts, list):
        raise SyncError(f"remote property has invalid {field_type} value")
    output = []
    for part in parts:
        if not isinstance(part, dict):
            raise SyncError(f"remote property has invalid {field_type} content")
        text = part.get("plain_text")
        if not isinstance(text, str):
            content = part.get("text", {}).get("content") if isinstance(part.get("text"), dict) else None
            if not isinstance(content, str):
                raise SyncError(f"remote property has invalid {field_type} content")
            text = content
        output.append(text)
    return "".join(output)


def remote_values(properties: Any) -> dict[str, Any]:
    if not isinstance(properties, dict):
        raise SyncError("remote page has no properties object")
    missing = sorted(set(PROPERTY_TYPES) - set(properties))
    if missing:
        raise SyncError(f"remote page is missing managed properties: {', '.join(missing)}")
    result: dict[str, Any] = {}
    for name, field_type in PROPERTY_TYPES.items():
        prop = properties[name]
        if field_type in ("title", "rich_text"):
            result[name] = read_text(prop, field_type)
        elif field_type == "number":
            value = prop.get("number") if isinstance(prop, dict) else None
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                raise SyncError(f"remote property {name} has invalid number value")
            result[name] = int(value) if value == int(value) else value
        else:
            selected = prop.get("select") if isinstance(prop, dict) else None
            value = selected.get("name") if isinstance(selected, dict) else None
            if not isinstance(value, str):
                raise SyncError(f"remote property {name} has invalid select value")
            result[name] = value
    return result


def load_tsv(path: Path) -> list[LocalRow]:
    if path.is_symlink() or not path.is_file():
        raise SyncError(f"TSV is missing or not a regular file: {path}")
    try:
        with path.open(encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream, delimiter="\t")
            if reader.fieldnames != HEADERS:
                raise SyncError(f"TSV headers must be exactly: {', '.join(HEADERS)}")
            raw_rows = list(reader)
    except UnicodeDecodeError as exc:
        raise SyncError(f"TSV is not valid UTF-8: {path}") from exc
    if not raw_rows:
        raise SyncError("TSV has no data rows")
    rows: list[LocalRow] = []
    seen: set[str] = set()
    for line, row in enumerate(raw_rows, 2):
        if None in row:
            raise SyncError(f"TSV line {line} has extra fields")
        relation, column = row["relation"].strip(), row["column"].strip()
        kind = row["kind"].strip()
        if not relation or not column:
            raise SyncError(f"TSV line {line} requires relation and column")
        if kind not in {"table", "view"}:
            raise SyncError(f"TSV line {line} kind must be table or view")
        try:
            ordinal = int(row["ordinal"])
        except ValueError as exc:
            raise SyncError(f"TSV line {line} ordinal must be a positive integer") from exc
        if ordinal < 1 or str(ordinal) != row["ordinal"].strip():
            raise SyncError(f"TSV line {line} ordinal must be a positive integer")
        key = f"{relation}::{column}"
        if key in seen:
            raise SyncError(f"TSV has duplicate key: {key}")
        seen.add(key)
        values = {
            "Column": column, "Table": relation, "Type": row["type"],
            "Direct upstream": row["direct upstream source / derivation"],
            "Example / format": row["example / structure"],
            "Description": row["description"], "NULL meaning": row["null meaning"],
            "Order": ordinal, "Kind": kind, "Key": key,
        }
        rows.append(LocalRow(key, values))
    return rows


def validate_schema(client: NotionClient, data_source_id: str) -> None:
    payload = client.request(f"/v1/data_sources/{data_source_id}")
    properties = payload.get("properties")
    if not isinstance(properties, dict):
        raise SyncError("data source response has no properties object")
    problems = []
    for name, expected in PROPERTY_TYPES.items():
        actual = properties.get(name, {}).get("type") if isinstance(properties.get(name), dict) else None
        if actual != expected:
            problems.append(f"{name} (expected {expected}, got {actual or 'missing'})")
    if problems:
        raise SyncError("data source schema mismatch: " + "; ".join(problems))


def query_all(client: NotionClient, data_source_id: str) -> list[RemoteRow]:
    output: list[RemoteRow] = []
    cursor = None
    while True:
        body: dict[str, Any] = {"page_size": 100}
        if cursor:
            body["start_cursor"] = cursor
        payload = client.request(f"/v1/data_sources/{data_source_id}/query", "POST", body)
        results = payload.get("results")
        if not isinstance(results, list):
            raise SyncError("data source query returned no results list")
        for item in results:
            page_id = item.get("id") if isinstance(item, dict) else None
            if not isinstance(page_id, str) or not page_id:
                raise SyncError("data source query returned a page without an ID")
            output.append(RemoteRow(page_id, remote_values(item.get("properties"))))
        has_more = payload.get("has_more")
        cursor = payload.get("next_cursor")
        if has_more is False:
            break
        if has_more is not True or not isinstance(cursor, str) or not cursor:
            raise SyncError("data source query returned invalid pagination metadata")
    return output


def values_hash(values: dict[str, Any]) -> str:
    raw = json.dumps(values, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(raw).hexdigest()


def load_state(path: Path, data_source_id: str) -> dict[str, Any]:
    if not path.exists():
        return {}
    if path.is_symlink() or not path.is_file():
        raise SyncError(f"state path is not a regular file: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SyncError(f"cannot read valid state from {path}") from exc
    if not isinstance(payload, dict) or payload.get("version") != STATE_VERSION or not isinstance(payload.get("records"), dict):
        raise SyncError(f"state file has an unsupported shape: {path}")
    if payload.get("data_source_id") != data_source_id:
        raise SyncError("state file belongs to a different data source")
    return payload["records"]


def configured_data_source(path: Path) -> str:
    if path.is_symlink() or not path.is_file():
        raise SyncError(f"config is missing or not a regular file: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SyncError(f"cannot read valid config from {path}") from exc
    value = payload.get("data_source_id") if isinstance(payload, dict) else None
    if not isinstance(value, str) or not value.strip():
        raise SyncError(f"config has no data_source_id: {path}")
    return value


def save_state(path: Path, data_source_id: str, rows: list[RemoteRow]) -> None:
    records = {row.values["Key"]: {"page_id": row.page_id, "hash": values_hash(row.values), "values": row.values}
               for row in rows}
    payload = {"version": STATE_VERSION, "data_source_id": data_source_id, "records": records}
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def plan(local: list[LocalRow], remote: list[RemoteRow], state: dict[str, Any]) -> tuple[list[LocalRow], list[tuple[LocalRow, RemoteRow]], list[RemoteRow], list[str]]:
    remote_by_key: dict[str, RemoteRow] = {}
    problems: list[str] = []
    for row in remote:
        key = row.values["Key"]
        if not key:
            problems.append(f"remote page {row.page_id} has a missing Key")
        elif key in remote_by_key:
            problems.append(f"remote duplicate Key {key}: {remote_by_key[key].page_id}, {row.page_id}")
        else:
            remote_by_key[key] = row
    local_by_key = {row.key: row for row in local}
    removed = sorted(set(remote_by_key) - set(local_by_key))
    problems.extend(f"remote Key is absent from TSV (not deleted): {key}" for key in removed)
    problems.extend(f"state Key is absent from TSV (not deleted): {key}" for key in sorted(set(state) - set(local_by_key)))
    creates: list[LocalRow] = []
    updates: list[tuple[LocalRow, RemoteRow]] = []
    unchanged: list[RemoteRow] = []
    for row in local:
        current = remote_by_key.get(row.key)
        if current is None:
            if row.key in state:
                problems.append(f"state Key is missing remotely (not recreated): {row.key}")
            else:
                creates.append(row)
            continue
        saved = state.get(row.key)
        if current.values == row.values:
            unchanged.append(current)
        elif not isinstance(saved, dict) or saved.get("page_id") != current.page_id or not isinstance(saved.get("values"), dict):
            problems.append(f"unmanaged remote values differ for {row.key}; refusing overwrite")
        elif current.values != saved["values"]:
            problems.append(f"remote managed fields changed since last sync for {row.key}; refusing overwrite")
        else:
            updates.append((row, current))
    return creates, updates, unchanged, problems


def apply_one(client: NotionClient, data_source_id: str,
              action: tuple[str, LocalRow, RemoteRow | None]) -> None:
    operation, row, baseline = action
    if operation == "create":
        body = {"parent": {"type": "data_source_id", "data_source_id": data_source_id},
                "properties": notion_properties(row.values)}
        payload = client.request("/v1/pages", "POST", body, retry_transient=False)
    else:
        assert baseline is not None
        latest = client.request(f"/v1/pages/{baseline.page_id}")
        if remote_values(latest.get("properties")) != baseline.values:
            raise SyncError(f"remote managed fields changed after preflight for {row.key}; refusing overwrite")
        payload = client.request(f"/v1/pages/{baseline.page_id}", "PATCH",
                                 {"properties": notion_properties(row.values)}, retry_transient=False)
    if not isinstance(payload.get("id"), str):
        raise SyncError(f"{operation} {row.key} returned no page ID")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Preview or apply TSV field rows to an existing Notion data source.")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG,
                        help="JSON config used when --data-source is omitted")
    parser.add_argument("--data-source", help="override the configured existing Notion data source ID")
    parser.add_argument("--tsv", type=Path, default=DEFAULT_TSV)
    parser.add_argument("--state", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--ntn", default="ntn", help="ntn executable path")
    parser.add_argument("--apply", action="store_true", help="write only after all preflight checks pass")
    args = parser.parse_args(argv)
    executable = args.ntn if os.path.dirname(args.ntn) else which(args.ntn)
    if not executable or not os.access(executable, os.X_OK):
        print("error: ntn executable not found or not executable", file=sys.stderr)
        return 2
    try:
        data_source_id = args.data_source or configured_data_source(args.config)
        local = load_tsv(args.tsv)
        state = load_state(args.state, data_source_id)
        client = NotionClient(executable)
        validate_schema(client, data_source_id)
        remote = query_all(client, data_source_id)
        creates, updates, unchanged, problems = plan(local, remote, state)
        print(f"PLAN rows={len(local)} create={len(creates)} update={len(updates)} unchanged={len(unchanged)} issues={len(problems)}")
        for problem in problems:
            print(f"ISSUE {problem}", file=sys.stderr)
        if problems:
            raise SyncError("preflight found conflicts or unmanaged rows; no writes performed")
        if not args.apply:
            return 0
        actions = [("create", row, None) for row in creates] + [("update", row, remote) for row, remote in updates]
        completed = 0
        with ThreadPoolExecutor(max_workers=WORKERS) as executor:
            for offset in range(0, len(actions), WORKERS):
                futures = [executor.submit(apply_one, client, data_source_id, action)
                           for action in actions[offset:offset + WORKERS]]
                for future in as_completed(futures):
                    future.result()
                    completed += 1
                    if completed % 100 == 0 or completed == len(actions):
                        print(f"APPLY progress={completed}/{len(actions)}", flush=True)
        verified = query_all(client, data_source_id)
        verified_by_key = {row.values["Key"]: row for row in verified}
        if len(verified) != len(local) or set(verified_by_key) != {row.key for row in local}:
            raise SyncError(f"readback count/key mismatch: expected {len(local)}, got {len(verified)}")
        mismatches = [row.key for row in local if verified_by_key[row.key].values != row.values]
        if mismatches:
            raise SyncError("readback value mismatch: " + ", ".join(mismatches[:10]))
        save_state(args.state, data_source_id, verified)
        print(f"APPLY verified={len(verified)} writes={len(actions)} state={args.state}")
        return 0
    except SyncError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
