#!/usr/bin/env python3
"""Safely push explicitly annotated Markdown files to existing Notion pages.

The default mode only validates files and reads every destination page.  Writes
require ``--apply``.  Applying is deliberately non-transactional: an edit that
has already succeeded is not rolled back if a later edit or verification fails.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlparse


UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
URL_UUID_RE = re.compile(r"(?i)(?<![0-9a-f])([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{32})(?![0-9a-f])")
H1_RE = re.compile(r"^#\s+(.+?)\s*$")
KEYS = {"notion-id", "notion-url", "notion-sync"}
ALLOWED_HOSTS = {"notion.so", "www.notion.so", "app.notion.com"}


class SyncError(Exception):
    pass


def canonical_uuid(value: str) -> str:
    if not UUID_RE.fullmatch(value):
        raise SyncError("notion-id must be a canonical UUID")
    return value.lower()


def parse_document(path: Path, repo_root: Path) -> tuple[str, str, bytes, str, str]:
    try:
        resolved = path.resolve(strict=True)
    except OSError as exc:
        raise SyncError(f"cannot resolve {path}: {exc}") from exc
    if not resolved.is_file() or resolved.suffix != ".md":
        raise SyncError(f"expected an existing .md file: {path}")
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise SyncError(f"file is outside the repository: {path}") from exc
    if resolved.parent != repo_root:
        raise SyncError(f"only top-level repository Markdown files may be synced: {path}")
    try:
        resolved.relative_to(repo_root / "comms")
    except ValueError:
        pass
    else:
        raise SyncError(f"comms/ files are not sync inputs: {path}")

    raw = resolved.read_bytes()
    lines = raw.splitlines(keepends=True)
    if not lines or lines[0].rstrip(b"\r\n") != b"---":
        raise SyncError(f"{path}: YAML frontmatter must be the first line")

    close = None
    for index in range(1, len(lines)):
        if lines[index].rstrip(b"\r\n") == b"---":
            close = index
            break
    if close is None:
        raise SyncError(f"{path}: YAML frontmatter has no closing ---")

    metadata: dict[str, str] = {}
    for line in lines[1:close]:
        if not line.endswith((b"\n", b"\r")):
            raise SyncError(f"{path}: malformed YAML line")
        text = line.decode("utf-8", "strict").rstrip("\r\n")
        match = re.fullmatch(r"([a-z][a-z0-9-]*): ([^\t\r\n]+)", text)
        if not match or match.group(1) not in KEYS:
            raise SyncError(f"{path}: frontmatter must contain only notion-id, notion-url, notion-sync scalar keys")
        key, value = match.groups()
        if key in metadata:
            raise SyncError(f"{path}: duplicate frontmatter key {key}")
        metadata[key] = value
    if set(metadata) != KEYS:
        raise SyncError(f"{path}: frontmatter requires notion-id, notion-url, and notion-sync")
    if metadata["notion-sync"] != "push":
        raise SyncError(f"{path}: notion-sync must be push")

    page_id = canonical_uuid(metadata["notion-id"])
    parsed = urlparse(metadata["notion-url"])
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS or not parsed.path:
        raise SyncError(f"{path}: notion-url must be an HTTPS Notion page URL")
    candidates = URL_UUID_RE.findall(parsed.path)
    if len(candidates) != 1 or candidates[0].replace("-", "").lower() != page_id.replace("-", ""):
        raise SyncError(f"{path}: notion-url UUID does not match notion-id")

    body = b"".join(lines[close + 1 :])
    if not body.strip():
        raise SyncError(f"{path}: Markdown body is empty")
    if first_h1(body) is None:
        raise SyncError(f"{path}: Markdown body must contain a meaningful H1")
    return page_id, metadata["notion-url"], body, str(resolved), first_h1(body) or ""


def first_h1(markdown: bytes) -> str | None:
    for line in markdown.decode("utf-8", "replace").splitlines():
        if line.strip():
            match = H1_RE.fullmatch(line.strip())
            return match.group(1).strip() if match else None
    return None


def inspect_page(raw: bytes, expected_id: str, path: str, require_body: bool) -> tuple[str, dict, str | None]:
    try:
        payload = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SyncError(f"{path}: ntn pages get returned invalid JSON") from exc
    if not isinstance(payload, dict) or not isinstance(payload.get("page"), dict):
        raise SyncError(f"{path}: pages get returned an unexpected JSON shape")
    page = payload["page"]
    actual_id = page.get("id")
    parent = page.get("parent")
    properties = page.get("properties")
    title_property = properties.get("title") if isinstance(properties, dict) else None
    title_parts = title_property.get("title") if isinstance(title_property, dict) else None
    title = "".join(item.get("plain_text", "") for item in title_parts or [] if isinstance(item, dict)).strip()
    markdown_value = payload.get("markdown")
    nested_id = None
    if isinstance(markdown_value, dict):
        nested_id = markdown_value.get("id")
        markdown = markdown_value.get("markdown")
        if markdown_value.get("truncated") is True or markdown_value.get("unknown_block_ids"):
            raise SyncError(f"{path}: pages get reported truncated or unknown blocks")
    else:
        markdown = markdown_value
    def has_unknown_blocks(value: object) -> bool:
        if isinstance(value, dict):
            if value.get("unknown_block_ids"):
                return True
            return any(has_unknown_blocks(item) for item in value.values())
        if isinstance(value, list):
            return any(has_unknown_blocks(item) for item in value)
        return False
    if has_unknown_blocks(payload):
        raise SyncError(f"{path}: pages get reported truncated or unknown blocks")
    if nested_id is not None and (not isinstance(nested_id, str) or canonical_uuid(nested_id) != expected_id):
        raise SyncError(f"{path}: page markdown returned an unexpected page ID")
    if not isinstance(actual_id, str) or canonical_uuid(actual_id) != expected_id:
        raise SyncError(f"{path}: pages get returned an unexpected page ID")
    if not title or not isinstance(parent, dict) or not parent:
        raise SyncError(f"{path}: pages get did not return a meaningful title and full parent")
    if markdown is not None and not isinstance(markdown, str):
        raise SyncError(f"{path}: pages get returned invalid markdown")
    if require_body and (not markdown or not markdown.strip()):
        raise SyncError(f"{path}: pages get returned an empty body after edit")
    return title, parent, first_h1(markdown.encode()) if markdown else None


def run_get(ntn: str, page_id: str, path: str, require_body: bool) -> tuple[str, dict, str | None]:
    env = os.environ.copy()
    env["NOTION_KEYRING"] = "0"
    result = subprocess.run([ntn, "pages", "get", page_id, "--json"], capture_output=True, env=env)
    if result.returncode:
        raise SyncError(f"{path}: pages get failed (exit {result.returncode})")
    return inspect_page(result.stdout, page_id, path, require_body)


def run_edit(ntn: str, page_id: str, body: bytes, path: str) -> None:
    env = os.environ.copy()
    env["NOTION_KEYRING"] = "0"
    result = subprocess.run([ntn, "pages", "edit", page_id], input=body, capture_output=True, env=env)
    if result.returncode:
        raise SyncError(f"{path}: pages edit failed (exit {result.returncode})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check or push annotated Notion Markdown pages. --apply writes; apply is non-transactional if a later edit fails."
    )
    parser.add_argument("--apply", action="store_true", help="perform edits after all read-only preflights succeed")
    parser.add_argument("--ntn", default="ntn", help="ntn executable path (default: ntn)")
    parser.add_argument("files", nargs="+", help="explicit repository .md files")
    args = parser.parse_args(argv)
    ntn = args.ntn
    if not os.path.dirname(ntn):
        from shutil import which
        ntn = which(ntn) or ""
    if not ntn or not os.access(ntn, os.X_OK):
        print("error: ntn executable not found or not executable", file=sys.stderr)
        return 2
    repo_root = Path(__file__).resolve().parent.parent
    documents = []
    try:
        for name in args.files:
            page_id, url, body, path, h1 = parse_document(Path(name), repo_root)
            documents.append((page_id, url, body, path, h1))
        paths = [item[3] for item in documents]
        ids = [item[0] for item in documents]
        if len(paths) != len(set(paths)):
            raise SyncError("duplicate local file arguments")
        if len(ids) != len(set(ids)):
            raise SyncError("duplicate notion-id arguments")
        snapshots = []
        for page_id, _url, body, path, _local_h1 in documents:
            title, parent, remote_h1 = run_get(ntn, page_id, path, False)
            snapshots.append((title, parent, remote_h1))
            print(f"CHECK {path} -> {page_id} (body {len(body)} bytes)")
        if not args.apply:
            return 0
        for (page_id, _url, body, path, local_h1), (title, parent, _remote_h1) in zip(documents, snapshots):
            run_edit(ntn, page_id, body, path)
            new_title, new_parent, new_h1 = run_get(ntn, page_id, path, True)
            if new_title != title or new_parent != parent or new_h1 != local_h1:
                raise SyncError(f"{path}: title, parent, or H1 changed during edit")
            print(f"APPLY {path} -> {page_id} verified")
    except SyncError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
