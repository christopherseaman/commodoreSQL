#!/usr/bin/env python3
"""Publish the generated data-dictionary TSVs as managed Notion file blocks."""

from __future__ import annotations

import argparse
import ast
import csv
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from typing import Any
from urllib.request import Request, urlopen


PAGE_ID = "3cbd9fdd-1a1a-8082-b697-ca7f5ef1d6ed"
TOGGLE_CAPTION = "Downloads"
STATE_VERSION = 1
CONTENT_TYPE = "text/tab-separated-values"
REQUEST_INTERVAL_SECONDS = 1.05
TIMEOUT_SECONDS = 90
SAFE_READ_ATTEMPTS = 4
TRANSIENT_ERRORS = ("429", "rate limit", "timed out", "timeout", "temporarily unavailable",
                    "connection reset", "502", "503", "504")


class SyncError(Exception):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def rich_text(text: str) -> list[dict[str, Any]]:
    return [{"type": "text", "text": {"content": text}}]


def plain_text(items: object) -> str:
    if not isinstance(items, list):
        return ""
    return "".join(x.get("plain_text", "") for x in items if isinstance(x, dict))


def dictionary_relations(root: Path) -> tuple[str, ...]:
    generator_path = root / "scripts/generate_data_dictionary.py"
    try:
        tree = ast.parse(generator_path.read_text(encoding="utf-8"), filename=str(generator_path))
        assignment = next(
            node for node in tree.body
            if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name)
            and node.target.id == "DICTIONARY_RELATIONS"
        )
        relations = ast.literal_eval(assignment.value)
    except (OSError, SyntaxError, StopIteration, ValueError) as exc:
        raise SyncError(f"cannot load dictionary generator: {generator_path}") from exc
    if (not isinstance(relations, tuple) or not relations or
            any(not isinstance(name, str) or not name for name in relations) or
            len(relations) != len(set(relations))):
        raise SyncError("generator DICTIONARY_RELATIONS must be a nonempty unique tuple")
    return relations


def load_artifacts(root: Path) -> list[dict[str, Any]]:
    global_path = root / "docs/data-dictionary.tsv"
    per_dir = root / "docs/data-dictionary"
    relations = dictionary_relations(root)
    discovered = {path.stem: path for path in per_dir.glob("*.tsv")}
    extras = set(discovered) - set(relations)
    missing = set(relations) - set(discovered)
    if extras or missing:
        raise SyncError(f"per-table TSV set differs from generator allowlist; missing={sorted(missing)}, extra={sorted(extras)}")
    paths = [global_path, *(discovered[name] for name in relations)]
    if not global_path.is_file():
        raise SyncError("global data-dictionary.tsv is missing")
    artifacts = []
    global_rows: list[dict[str, str]]
    with global_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if not reader.fieldnames or reader.fieldnames[0] != "relation":
            raise SyncError("global TSV must begin with a relation header")
        global_rows = list(reader)
    if not global_rows:
        raise SyncError("global TSV has no data rows")
    relations = {row["relation"] for row in global_rows}
    if relations != set(dictionary_relations(root)):
        raise SyncError("per-table TSV names do not match global relation values")
    global_fields = list(global_rows[0])
    for path in paths:
        if path.is_symlink() or not path.is_file():
            raise SyncError(f"artifact is not a regular file: {path}")
        data = path.read_bytes()
        if not data or b"\x00" in data:
            raise SyncError(f"artifact is empty or binary: {path}")
        artifacts.append({"name": path.name, "path": path, "bytes": data, "sha256": digest(data)})
    for artifact in artifacts[1:]:
        with artifact["path"].open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            rows = list(reader)
            expected = [row for row in global_rows if row["relation"] == artifact["path"].stem]
            if reader.fieldnames != global_fields or rows != expected:
                raise SyncError(f"{artifact['name']} is not the exact global TSV slice")
    return artifacts


class Notion:
    def __init__(self, executable: str, interval: float = REQUEST_INTERVAL_SECONDS):
        self.executable = executable
        self.interval = interval
        self.last_call = 0.0
        self.calls = 0

    def _wait(self) -> None:
        delay = self.interval - (time.monotonic() - self.last_call)
        if delay > 0:
            time.sleep(delay)

    def call(self, args: list[str], body: dict[str, Any] | None = None,
             input_bytes: bytes | None = None, safe_retry: bool = False) -> dict[str, Any]:
        attempts = SAFE_READ_ATTEMPTS if safe_retry else 1
        for attempt in range(attempts):
            self._wait()
            env = os.environ.copy()
            env["NOTION_KEYRING"] = "0"
            payload = input_bytes if input_bytes is not None else (
                json.dumps(body, separators=(",", ":")).encode() if body is not None else None)
            try:
                result = subprocess.run([self.executable, *args], input=payload, capture_output=True,
                                        env=env, timeout=TIMEOUT_SECONDS)
            except OSError as exc:
                raise SyncError(f"ntn request failed: {exc}") from exc
            except subprocess.TimeoutExpired as exc:
                if safe_retry and attempt + 1 < attempts:
                    time.sleep(2 ** attempt)
                    continue
                raise SyncError(f"ntn request failed: {exc}") from exc
            self.last_call = time.monotonic()
            self.calls += 1
            if result.returncode:
                detail = result.stderr.decode("utf-8", "replace").strip()
                transient = any(marker in detail.lower() for marker in TRANSIENT_ERRORS)
                if safe_retry and transient and attempt + 1 < attempts:
                    time.sleep(2 ** attempt)
                    continue
                raise SyncError(f"ntn {' '.join(args[:3])} failed: {detail or 'unknown error'}")
            try:
                value = json.loads(result.stdout)
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                raise SyncError("ntn returned invalid JSON") from exc
            if not isinstance(value, dict):
                raise SyncError("ntn returned an unexpected JSON shape")
            return value
        raise SyncError("ntn safe read exhausted retries")

    def children(self, block_id: str) -> list[dict[str, Any]]:
        output, cursor = [], None
        while True:
            args = ["api", f"/v1/blocks/{block_id}/children", "--method", "GET", "page_size==100"]
            if cursor:
                args.append(f"start_cursor=={cursor}")
            page = self.call(args, safe_retry=True)
            results = page.get("results")
            if not isinstance(results, list):
                raise SyncError("block children response has no results list")
            output.extend(x for x in results if isinstance(x, dict))
            if not page.get("has_more"):
                return output
            cursor = page.get("next_cursor")
            if not isinstance(cursor, str):
                raise SyncError("paginated response has no next cursor")

    def upload(self, artifact: dict[str, Any]) -> str:
        value = self.call(["files", "create", "--filename", artifact["name"],
                           "--content-type", CONTENT_TYPE, "--json"], input_bytes=artifact["bytes"])
        if value.get("object") != "file_upload" or value.get("status") != "uploaded" or not isinstance(value.get("id"), str):
            raise SyncError(f"upload did not complete for {artifact['name']}")
        return value["id"]

    def append_toggle(self, upload_ids: dict[str, str], artifacts: list[dict[str, Any]]) -> str:
        files = [file_request(a["name"], upload_ids[a["name"]]) for a in artifacts]
        toggle = {"object": "block", "type": "toggle",
                  "toggle": {"rich_text": rich_text(TOGGLE_CAPTION), "children": files}}
        value = self.call(["api", f"/v1/blocks/{PAGE_ID}/children", "--method", "PATCH"],
                          {"children": [toggle], "position": {"type": "start"}})
        results = value.get("results")
        if isinstance(results, list):
            toggles = [item for item in results if isinstance(item, dict) and item.get("type") == "toggle"]
            if len(toggles) == 1:
                return toggles[0]["id"]
        if value.get("type") == "toggle" and isinstance(value.get("id"), str):
            return value["id"]
        # Some API/CLI versions return only the appended child blocks. Resolve the
        # just-created, uniquely captioned toggle from the parent instead.
        matches = [block for block in self.children(PAGE_ID) if block.get("type") == "toggle" and
                   plain_text(block.get("toggle", {}).get("rich_text")) == TOGGLE_CAPTION]
        if len(matches) != 1:
            raise SyncError("toggle creation succeeded but its unique readback could not be resolved")
        return matches[0]["id"]

    def update_file(self, block_id: str, name: str, upload_id: str) -> None:
        self.call(["api", f"/v1/blocks/{block_id}", "--method", "PATCH"],
                  {"type": "file", "file": update_file_payload(name, upload_id)})

    def block(self, block_id: str) -> dict[str, Any]:
        value = self.call(["api", f"/v1/blocks/{block_id}", "--method", "GET"], safe_retry=True)
        if value.get("id") != block_id or value.get("type") != "file":
            raise SyncError(f"file block changed or disappeared before update: {block_id}")
        return value


def file_payload(name: str, upload_id: str) -> dict[str, Any]:
    return {"type": "file_upload", "file_upload": {"id": upload_id}, "name": name,
            "caption": rich_text(name)}


def update_file_payload(name: str, upload_id: str) -> dict[str, Any]:
    return {"file_upload": {"id": upload_id}, "name": name,
            "caption": rich_text(name)}


def file_request(name: str, upload_id: str) -> dict[str, Any]:
    return {"object": "block", "type": "file", "file": file_payload(name, upload_id)}


def load_state(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise SyncError(f"invalid state file: {path}") from exc
    if not isinstance(value, dict) or value.get("version") != STATE_VERSION or value.get("page_id") != PAGE_ID:
        raise SyncError(f"unsupported or mismatched state file: {path}")
    return value


def save_state(path: Path, toggle_id: str, artifacts: list[dict[str, Any]], blocks: dict[str, dict[str, Any]]) -> None:
    value = {"version": STATE_VERSION, "page_id": PAGE_ID, "toggle_id": toggle_id,
             "files": {a["name"]: {"block_id": blocks[a["name"]]["id"], "sha256": a["sha256"]}
                       for a in artifacts}}
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def find_toggle(page_blocks: list[dict[str, Any]], state: dict[str, Any] | None) -> dict[str, Any] | None:
    matches = [block for block in page_blocks if block.get("type") == "toggle" and
               plain_text(block.get("toggle", {}).get("rich_text")) == TOGGLE_CAPTION]
    if len(matches) > 1:
        raise SyncError("multiple exact Downloads toggles exist; refusing ambiguous ownership")
    if state:
        if len(matches) != 1 or matches[0].get("id") != state.get("toggle_id"):
            raise SyncError("managed Downloads toggle is missing or its ID changed")
        return matches[0]
    return matches[0] if matches else None


def inspect_files(children: list[dict[str, Any]], state: dict[str, Any] | None,
                  expected_names: set[str]) -> dict[str, dict[str, Any]]:
    files: dict[str, dict[str, Any]] = {}
    for block in children:
        if block.get("type") != "file":
            raise SyncError(f"unexpected non-file block inside managed Downloads toggle: {block.get('id')}")
        value = block.get("file", {})
        name = value.get("name") or plain_text(value.get("caption"))
        if not isinstance(name, str) or not name or name in files:
            raise SyncError("managed toggle contains an unnamed or duplicate file")
        files[name] = block
    extras = set(files) - expected_names
    missing = expected_names - set(files)
    if extras:
        raise SyncError(f"unexpected remote files in managed toggle: {', '.join(sorted(extras))}")
    if state:
        known = state.get("files")
        if not isinstance(known, dict):
            raise SyncError("state has no managed file map")
        deleted = set(known) - set(files)
        if deleted:
            raise SyncError(f"remote deletions detected (not auto-restored): {', '.join(sorted(deleted))}")
        for name, block in files.items():
            item = known.get(name)
            if not isinstance(item, dict) or item.get("block_id") != block.get("id"):
                raise SyncError(f"unexpected remote edit/state mismatch for {name}")
    if missing and state:
        # New local artifacts are supported, but prior managed keys are handled above as deletions.
        old_names = set(state.get("files", {}))
        missing_old = missing & old_names
        if missing_old:
            raise SyncError(f"remote deletions detected (not auto-restored): {', '.join(sorted(missing_old))}")
    return files


def remote_url(block: dict[str, Any]) -> str:
    value = block.get("file", {})
    kind = value.get("type")
    nested = value.get(kind, {}) if isinstance(kind, str) else {}
    url = nested.get("url") if isinstance(nested, dict) else None
    if not isinstance(url, str) or not url.startswith("https://"):
        raise SyncError(f"file block {block.get('id')} has no downloadable HTTPS URL")
    return url


def download_digest(block: dict[str, Any], name: str) -> str:
    request = Request(remote_url(block), headers={"User-Agent": "commodoreSQL-dictionary-sync/1"})
    try:
        with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return digest(response.read())
    except OSError as exc:
        raise SyncError(f"download verification failed for {name}: {exc}") from exc


def remote_digests(artifacts: list[dict[str, Any]], blocks: dict[str, dict[str, Any]]) -> dict[str, str]:
    return {artifact["name"]: download_digest(blocks[artifact["name"]], artifact["name"])
            for artifact in artifacts}


def verify_downloads(artifacts: list[dict[str, Any]], blocks: dict[str, dict[str, Any]]) -> None:
    hashes = remote_digests(artifacts, blocks)
    for artifact in artifacts:
        if hashes[artifact["name"]] != artifact["sha256"]:
            raise SyncError(f"downloaded bytes do not match local SHA256 for {artifact['name']}")


def reconcile_remote(artifacts: list[dict[str, Any]], blocks: dict[str, dict[str, Any]],
                     state: dict[str, Any]) -> list[dict[str, Any]]:
    hashes = remote_digests(artifacts, blocks)
    changed = []
    for artifact in artifacts:
        name = artifact["name"]
        saved = state["files"][name]["sha256"]
        current = hashes[name]
        desired = artifact["sha256"]
        if current != saved and current != desired:
            raise SyncError(f"unexpected remote file edit for {name}; refusing to overwrite it")
        if current != desired:
            changed.append(artifact)
    return changed


def verify_recovery(artifacts: list[dict[str, Any]], blocks: dict[str, dict[str, Any]]) -> None:
    hashes = remote_digests(artifacts, blocks)
    mismatches = [a["name"] for a in artifacts if hashes[a["name"]] != a["sha256"]]
    if mismatches:
        raise SyncError("unmanaged Downloads toggle does not exactly match local files: " +
                        ", ".join(mismatches))


def run(args: argparse.Namespace) -> dict[str, Any]:
    root = Path(__file__).resolve().parent.parent
    page_id = args.page
    if page_id is None:
        try:
            config = json.loads((root / args.config).read_text())
            page_id = config["page_id"]
        except (OSError, json.JSONDecodeError, KeyError, TypeError) as exc:
            raise SyncError(f"cannot read page_id from config: {args.config}") from exc
    if page_id != PAGE_ID:
        raise SyncError(f"unexpected Data Dictionary page_id: {page_id}")
    artifacts = load_artifacts(root)
    expected_names = {a["name"] for a in artifacts}
    state_path = root / args.state
    state = load_state(state_path)
    notion = Notion(args.ntn, args.interval)
    page_blocks = notion.children(PAGE_ID)
    toggle = find_toggle(page_blocks, state)
    uploads = writes = 0
    if toggle is None:
        changed = artifacts
        if not args.apply:
            return {"mode": "preview", "toggle_id": None, "files": len(artifacts),
                    "uploads": len(changed), "writes": 1, "verified": 0, "requests": notion.calls}
        upload_ids = {}
        for artifact in changed:
            upload_ids[artifact["name"]] = notion.upload(artifact)
            uploads += 1
        toggle_id = notion.append_toggle(upload_ids, artifacts)
        writes += 1
        children = notion.children(toggle_id)
        blocks = inspect_files(children, None, expected_names)
    else:
        toggle_id = toggle["id"]
        blocks = inspect_files(notion.children(toggle_id), state, expected_names)
        if state is None:
            verify_recovery(artifacts, blocks)
            if args.apply:
                save_state(state_path, toggle_id, artifacts, blocks)
            return {"mode": "apply" if args.apply else "preview", "toggle_id": toggle_id,
                    "files": len(artifacts), "uploads": 0, "writes": 0,
                    "verified": len(artifacts), "requests": notion.calls,
                    "recovered": bool(args.apply)}
        new = [a for a in artifacts if a["name"] not in blocks]
        if new:
            raise SyncError("new local attachments require an explicit migration; no automatic append")
        changed = reconcile_remote(artifacts, blocks, state)
        if args.apply:
            for artifact in changed:
                guarded = notion.block(blocks[artifact["name"]]["id"])
                current = download_digest(guarded, artifact["name"])
                saved = state["files"][artifact["name"]]["sha256"]
                if current != saved:
                    if current == artifact["sha256"]:
                        continue
                    raise SyncError(f"remote file changed before update: {artifact['name']}")
                upload_id = notion.upload(artifact)
                uploads += 1
                notion.update_file(blocks[artifact["name"]]["id"], artifact["name"], upload_id)
                writes += 1
            if changed:
                blocks = inspect_files(notion.children(toggle_id), state, expected_names)
    if not args.apply:
        return {"mode": "preview", "toggle_id": toggle_id, "files": len(artifacts),
                "uploads": len(changed), "writes": len(changed),
                "verified": len(artifacts), "requests": notion.calls}
    verify_downloads(artifacts, blocks)
    save_state(state_path, toggle_id, artifacts, blocks)
    return {"mode": "apply", "toggle_id": toggle_id, "files": len(artifacts),
            "uploads": uploads, "writes": writes, "verified": len(artifacts), "requests": notion.calls}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="perform uploads and block writes")
    parser.add_argument("--state", default=".notion/dictionary-downloads.json")
    parser.add_argument("--config", default="scripts/notion_dictionary.json")
    parser.add_argument("--page", help="override the configured Data Dictionary page UUID")
    parser.add_argument("--ntn", default="ntn")
    parser.add_argument("--interval", type=float, default=REQUEST_INTERVAL_SECONDS, help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        result = run(args)
    except SyncError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
