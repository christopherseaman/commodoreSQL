#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import importlib.util


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "sync_notion_docs.py"
PAGE = "12345678-1234-1234-1234-123456789abc"
SPEC = importlib.util.spec_from_file_location("sync_notion_docs", SCRIPT)
SYNC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SYNC)


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="notion-sync-", dir=ROOT))
        self.docs = []
        self.log = self.tmp / "log.jsonl"
        self.fake = self.tmp / "fake-ntn"
        self.state_file = self.tmp / "prose-state.json"
        self.fake.write_text("""#!/usr/bin/env python3
import json, os, sys
log = os.environ['FAKE_LOG']
stdin = sys.stdin.buffer.read().decode()
with open(log, 'a') as f: f.write(json.dumps({'argv': sys.argv[1:], 'keyring': os.environ.get('NOTION_KEYRING'), 'stdin': stdin})+'\\n')
if sys.argv[1:2] == ['api']:
 state = log + '.state.' + sys.argv[2].split('/')[-2]
 count = sum(1 for x in open(log) if '"api"' in x)
 mode = os.environ.get('API_MODE', 'sync')
 if mode == 'submit-fail':
  print('request body rejected: too large', file=sys.stderr)
  raise SystemExit(9)
 if mode == 'malformed':
  print('{not-json')
 elif mode == 'malformed-nested':
  print(json.dumps({'object': 'async_task', 'async_task': {'status': 'queued'}}))
 elif mode == 'async-fail':
  print(json.dumps({'object': 'async_task', 'id': 'task-1', 'status': 'failed', 'error': 'replacement failed'}))
 elif mode == 'timeout':
  print(json.dumps({'id': 'task-1', 'status': 'queued'}))
 elif mode == 'async':
  if count == 1: print(json.dumps({'object': 'async_task', 'id': 'task-1', 'status': 'queued', 'status_url': '/v1/async_tasks/task-1'}))
  elif count == 2: print(json.dumps({'object': 'async_task', 'id': 'task-1', 'status': 'running'}))
  else: print(json.dumps({'object': 'async_task', 'id': 'task-1', 'status': 'succeeded'}))
 elif mode == 'retrying':
  if count == 1: print(json.dumps({'object': 'async_task', 'id': 'task-1', 'status': 'queued'}))
  elif count == 2: print(json.dumps({'object': 'async_task', 'id': 'task-1', 'status': 'retrying'}))
  else: print(json.dumps({'object': 'async_task', 'id': 'task-1', 'status': 'succeeded'}))
 elif mode == 'nested-async':
  if count == 1: print(json.dumps({'object': 'async_task', 'async_task': {'id': 'task-1', 'status': 'queued'}}))
  else: print(json.dumps({'object': 'async_task', 'id': 'task-1', 'status': 'succeeded'}))
 else:
  request = json.loads(stdin)
  canonical = request['replace_content']['new_str'].replace('hello', 'Notion-rendered hello') if os.environ.get('CANONICALIZE') else request['replace_content']['new_str']
  open(state, 'w').write(canonical)
  print(json.dumps({'object': 'page_markdown', 'id': sys.argv[2].split('/')[-2], 'markdown': canonical, 'truncated': False, 'unknown_block_ids': []}))
 raise SystemExit(0)
if sys.argv[1:3] == ['pages', 'get']:
 state = log + '.state.' + sys.argv[3]
 if os.environ.get('FAIL_GET_ID') and sys.argv[3].endswith('abd'):
  raise SystemExit(7)
 if os.environ.get('FAIL_VERIFY') and sum(1 for x in open(log) if '"get"' in x) > 2:
  print('{}')
 else:
  get_count = sum(1 for x in open(log) if '"get"' in x)
  markdown = '' if os.environ.get('EMPTY_PAGE') else ('# Doc title\\n\\n## Wrong\\nbody' if os.environ.get('MISMATCH_HEADINGS') else (open(state).read() if os.path.exists(state) else os.environ.get('REMOTE_MARKDOWN', '# Doc title\\n\\nmeaningful body')))
  if os.environ.get('MUTATE_BEFORE_SECOND_GET') and get_count == 2: markdown += '\\nHUMAN EDIT'
  if os.environ.get('MULTI_TERMINAL_NEWLINE'): markdown += '\\n'
  print(json.dumps({'page': {'id': sys.argv[3], 'parent': {'block_id': 'parent-1', 'type': 'page_id'}, 'properties': {'title': {'type': 'title', 'title': [{'plain_text': 'Doc title'}]}}}, 'markdown': {'id': sys.argv[3], 'object': 'page_markdown', 'request_id': 'req-1', 'truncated': bool(os.environ.get('TRUNCATED')), 'unknown_block_ids': ['block-1'] if os.environ.get('UNKNOWN') else [], 'markdown': markdown}}))
""")
        self.fake.chmod(0o755)
        self.env = os.environ.copy()
        self.env["FAKE_LOG"] = str(self.log)

    def tearDown(self):
        for path in self.docs:
            path.unlink(missing_ok=True)
        shutil.rmtree(self.tmp)

    def root_doc_path(self, name):
        return ROOT / f".test-sync-{self.tmp.name}-{name.replace('/', '-')}"

    def data_dictionary_doc_path(self, name):
        path = ROOT / "docs" / "data-dictionary" / f".test-sync-{self.tmp.name}-{name}"
        self.docs.append(path)
        return path

    def doc(self, name="doc.md", body="# Doc title\n\nhello\n"):
        path = self.root_doc_path(name)
        path.write_text(f"---\nnotion-id: {PAGE}\nnotion-url: https://www.notion.so/workspace/{PAGE}\nnotion-sync: push\n---\n\n{body}")
        self.docs.append(path)
        return path

    def invoke(self, *args):
        return subprocess.run(["python3", str(SCRIPT), "--ntn", str(self.fake), "--state-file", str(self.state_file), *map(str, args)], cwd="/", env=self.env, text=True, capture_output=True)

    def seed_baseline(self, markdown="# Doc title\n\nmeaningful body", desired=None):
        entry = {"path": "test.md", "markdown": markdown}
        if desired is not None:
            entry["desired_sha256"] = SYNC.markdown_digest(SYNC.normalize_markdown(desired) or "")
        self.state_file.write_text(json.dumps({"version": 1, "pages": {PAGE: entry}}))

    def entries(self):
        return [json.loads(x) for x in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_check_does_not_write_and_strips_frontmatter(self):
        self.seed_baseline()
        result = self.invoke(self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = self.entries()
        self.assertEqual([e["argv"][:3] for e in entries], [["pages", "get", PAGE]])
        self.assertEqual(entries[0]["keyring"], "0")

    def test_unchanged_local_and_remote_make_zero_writes(self):
        desired = "# Doc title\n\nhello"
        remote = "# Doc title\n\nNotion-rendered hello"
        self.seed_baseline(remote, desired)
        self.env["REMOTE_MARKDOWN"] = remote
        result = self.invoke("--apply", self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([entry["argv"][0] for entry in self.entries()], ["pages"])

    def test_initialize_requires_remote_to_equal_desired(self):
        result = self.invoke("--initialize-state", self.doc())
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.state_file.exists())
        self.assertFalse(any(entry["argv"][0] == "api" for entry in self.entries()))
        self.log.unlink()
        self.env["REMOTE_MARKDOWN"] = "# Doc title\n\nhello"
        result = self.invoke("--initialize-state", self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)
        entry = json.loads(self.state_file.read_text())["pages"][PAGE]
        self.assertEqual(entry["markdown"], "# Doc title\n\nhello")
        self.assertEqual(entry["desired_sha256"], SYNC.markdown_digest("# Doc title\n\nhello"))

    def test_human_edit_detected_immediately_before_patch(self):
        self.seed_baseline()
        self.env["MUTATE_BEFORE_SECOND_GET"] = "1"
        result = self.invoke("--apply", self.doc())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("immediately before edit", result.stderr)
        self.assertFalse(any(entry["argv"][0] == "api" for entry in self.entries()))

    def test_live_shape_empty_page_is_valid_for_check(self):
        self.seed_baseline("")
        self.env["EMPTY_PAGE"] = "1"
        result = self.invoke(self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_truncated_or_unknown_markdown_is_rejected(self):
        for variable in ("TRUNCATED", "UNKNOWN"):
            self.env[variable] = "1"
            self.assertNotEqual(self.invoke(self.doc()).returncode, 0)
            self.env.pop(variable)

    def test_apply_order_and_body(self):
        self.seed_baseline()
        result = self.invoke("--apply", self.doc(body="# Doc title\n\n[hello](README.md) and [web](https://example.com)\n"))
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = self.entries()
        self.assertEqual([e["argv"][0] for e in entries], ["pages", "pages", "api", "pages"])
        request = json.loads(entries[2]["stdin"])
        self.assertIs(request["allow_async"], False)
        self.assertIn("replace_content", request)
        self.assertIn("hello and [web](https://example.com)", entries[2]["stdin"])
        self.assertNotIn("README.md", entries[2]["stdin"])
        self.assertEqual(entries[2]["keyring"], "0")

    def test_synchronous_success(self):
        self.seed_baseline()
        result = self.invoke("--apply", self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_heading_mismatch_is_reported(self):
        self.seed_baseline("# Doc title\n\n## Wrong\nbody")
        self.env["MISMATCH_HEADINGS"] = "1"
        result = self.invoke("--apply", self.doc())
        self.assertIn("title, parent, or H1", result.stderr)

    def test_terminal_newline_transport_difference_is_normalized(self):
        self.seed_baseline()
        self.env["MULTI_TERMINAL_NEWLINE"] = "1"
        result = self.invoke("--apply", self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_submit_failure_includes_error(self):
        self.seed_baseline()
        self.env["API_MODE"] = "submit-fail"
        result = self.invoke("--apply", self.doc())
        self.assertIn("too large", result.stderr)

    def test_malformed_response(self):
        self.seed_baseline()
        self.env["API_MODE"] = "malformed"
        result = self.invoke("--apply", self.doc())
        self.assertIn("invalid JSON", result.stderr)

    def test_bad_metadata_and_paths(self):
        bad = self.doc()
        bad.write_text(bad.read_text().replace(PAGE, "12345678-1234-1234-1234-123456789abd", 1))
        self.assertNotEqual(self.invoke(bad).returncode, 0)
        descriptor, outside_name = tempfile.mkstemp(suffix=".md")
        os.close(descriptor)
        outside = Path(outside_name)
        outside.write_text("---\nnotion-id: x\n---\n# x\n")
        try:
            self.assertNotEqual(self.invoke(outside).returncode, 0)
        finally:
            outside.unlink()
        comms_doc = ROOT / "comms" / f".{self.tmp.name}-doc.md"
        comms_doc.write_text(self.doc().read_text())
        try:
            self.assertNotEqual(self.invoke(comms_doc).returncode, 0)
        finally:
            comms_doc.unlink()

    def test_verification_failure_is_reported(self):
        self.seed_baseline()
        self.env["FAIL_VERIFY"] = "1"
        result = self.invoke("--apply", self.doc())
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(e["argv"][0] == "api" for e in self.entries()))

    def test_interrupted_canonicalized_edit_recovers_without_second_mutation(self):
        self.seed_baseline()
        self.env["CANONICALIZE"] = "1"
        self.env["FAIL_VERIFY"] = "1"
        doc = self.doc()
        first = self.invoke("--apply", doc)
        self.assertNotEqual(first.returncode, 0)
        self.assertEqual(sum(entry["argv"][0] == "api" for entry in self.entries()), 1)
        pending = json.loads(self.state_file.read_text())["pages"][PAGE]
        self.assertIn("pending_sha256", pending)
        self.assertIn("Notion-rendered hello", pending["markdown"])

        self.env.pop("FAIL_VERIFY")
        second = self.invoke("--apply", doc)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(sum(entry["argv"][0] == "api" for entry in self.entries()), 1)
        recovered = json.loads(self.state_file.read_text())["pages"][PAGE]
        self.assertNotIn("pending_sha256", recovered)
        self.assertIn("desired_sha256", recovered)

    def test_all_preflights_before_edit(self):
        one = self.doc("one.md")
        page2 = "12345678-1234-1234-1234-123456789abd"
        two = self.root_doc_path("two.md")
        two.write_text(self.doc("seed.md").read_text().replace(PAGE, page2))
        self.docs.append(two)
        self.env["FAIL_GET_ID"] = "1"
        result = self.invoke("--apply", one, two)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(e["argv"][0] == "api" for e in self.entries()))

    def test_duplicate_file_and_page_are_rejected(self):
        one = self.doc("duplicate.md")
        self.assertNotEqual(self.invoke(one, one).returncode, 0)
        two = self.root_doc_path("duplicate-two.md")
        two.write_text(one.read_text())
        self.docs.append(two)
        self.assertNotEqual(self.invoke(one, two).returncode, 0)

    def test_manifest_is_explicit_and_has_six_non_dictionary_documents(self):
        names = SYNC.load_manifest(Path("scripts/notion_sync_docs.txt"), ROOT)
        self.assertEqual(len(names), 6)
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(names, [
            "CMM-DATA-FLOW.md", "DASHBOARDS-REPORTS.md",
            "COURSE-MATERIAL-POPULATIONS.md", "MAILING-FLOW.md", "PRICING-CATALOG-MATCHING.md",
            "TOP125-REPORT.md",
        ])

    def test_publication_removes_only_local_links_outside_fences(self):
        markdown = b"""# Doc title

[Flow](CMM-DATA-FLOW.md) and [`report`](metabase/report.json), [web](https://example.com/x), [section](#part).

<page url=\"{{child}}\">Child</page>

```md
[literal](local.md)
```
"""
        published = SYNC.publication_markdown(markdown).decode()
        self.assertIn("Flow and `report`", published)
        self.assertIn("[web](https://example.com/x)", published)
        self.assertIn("[section](#part)", published)
        self.assertIn('<page url="{{child}}">Child</page>', published)
        self.assertIn("[literal](local.md)", published)

    def test_publication_promotes_headings_only_outside_code(self):
        markdown = b"""# Doc title

## Logic
### Diagram
#### table_name
##### Detail
###### Leaf

```mermaid
## literal
```

    ### indented literal
"""
        source = bytes(markdown)
        published = SYNC.publication_markdown(markdown)
        self.assertEqual(markdown, source)
        self.assertEqual(published.decode(), """# Doc title

# Logic
## Diagram
### table_name
#### Detail
##### Leaf

```mermaid
## literal
```

    ### indented literal
""")
        self.assertEqual(SYNC.heading_sequence(published), [
            (1, "Doc title"), (1, "Logic"), (2, "Diagram"),
            (3, "table_name"), (4, "Detail"), (5, "Leaf"),
        ])

    def test_publication_unwraps_only_paragraphs_and_list_continuations(self):
        markdown = b"""# Doc title

One soft-wrapped
paragraph.

- first item wraps
  onto another line
  - nested item
- second item\x20\x20
  explicit break

| A | B |
|---|---|
| one | two |

    indented
    code

> quoted
> lines

```mermaid
A --> B
```
"""
        self.assertEqual(SYNC.publication_markdown(markdown).decode(), """# Doc title

One soft-wrapped paragraph.

- first item wraps onto another line
  - nested item
- second item\x20\x20
  explicit break

| A | B |
|---|---|
| one | two |

    indented
    code

> quoted
> lines

```mermaid
A --> B
```
""")

    def test_joined_continuation_retains_explicit_break(self):
        for marker in ("  ", "\\"):
            source = f"A wrapped\ncontinuation{marker}\nnext line\n".encode()
            expected = f"A wrapped continuation{marker}\nnext line\n".encode()
            published = SYNC.publication_markdown(source)
            self.assertEqual(published, expected)
            # Publication is applied once at the source-to-Notion boundary. This
            # heading-free input also documents that unrelated content is stable.
            self.assertEqual(SYNC.publication_markdown(published), published)

    def test_apply_sends_unwrapped_body_and_then_becomes_noop(self):
        desired = "\n# Doc title\n\nhello wrapped"
        doc = self.doc(body="# Doc title\n\nhello\nwrapped\n")
        self.env["REMOTE_MARKDOWN"] = desired
        result = self.invoke("--initialize-state", doc)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(entry["argv"][0] == "api" for entry in self.entries()))

        self.log.unlink()
        result = self.invoke("--apply", doc)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(entry["argv"][0] == "api" for entry in self.entries()))

        self.log.unlink()
        doc.write_text(doc.read_text().replace("hello\nwrapped", "hello new\nwrapped"))
        result = self.invoke("--apply", doc)
        self.assertEqual(result.returncode, 0, result.stderr)
        request = json.loads(next(entry["stdin"] for entry in self.entries() if entry["argv"][0] == "api"))
        self.assertEqual(request["replace_content"]["new_str"], "\n# Doc title\n\nhello new wrapped\n")

    def test_apply_sends_promoted_headings_then_repeat_is_noop(self):
        doc = self.doc(body="# Doc title\n\n## Logic\n### Diagram\n#### table_name\n")
        self.seed_baseline()
        first = self.invoke("--apply", doc)
        self.assertEqual(first.returncode, 0, first.stderr)
        request = json.loads(next(entry["stdin"] for entry in self.entries() if entry["argv"][0] == "api"))
        self.assertEqual(request["replace_content"]["new_str"], "\n# Doc title\n\n# Logic\n## Diagram\n### table_name\n")

        self.log.unlink()
        second = self.invoke("--apply", doc)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertFalse(any(entry["argv"][0] == "api" for entry in self.entries()))

    def test_heading_promotion_does_not_hide_remote_conflict(self):
        self.seed_baseline("# Doc title\n\n# Logic\nold body")
        self.env["REMOTE_MARKDOWN"] = "# Doc title\n\n# Logic\nhuman edit"
        result = self.invoke("--apply", self.doc(body="# Doc title\n\n## Logic\nnew body\n"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("remote content changed", result.stderr)
        self.assertFalse(any(entry["argv"][0] == "api" for entry in self.entries()))

    def test_unwrapping_does_not_hide_remote_conflict(self):
        self.seed_baseline("# Doc title\n\nold body")
        self.env["REMOTE_MARKDOWN"] = "# Doc title\n\nhuman edit"
        result = self.invoke("--apply", self.doc(body="# Doc title\n\nhello\nwrapped\n"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("remote content changed", result.stderr)
        self.assertFalse(any(entry["argv"][0] == "api" for entry in self.entries()))

    def test_explicit_dictionary_publication_is_rejected_before_network(self):
        result = self.invoke(ROOT / "DATA-DICTIONARY.md")
        self.assertEqual(result.returncode, 2)
        self.assertIn("sync_notion_dictionary.py", result.stderr)
        self.assertIn("sync_notion_dictionary_downloads.py", result.stderr)
        self.assertFalse(self.log.exists())

    def test_direct_dictionary_child_is_rejected_before_network(self):
        path = self.data_dictionary_doc_path("allowed.md")
        path.write_text(f"---\nnotion-id: {PAGE}\nnotion-url: https://www.notion.so/workspace/{PAGE}\nnotion-sync: push\n---\n# Doc title\n\nhello\n")
        result = self.invoke(path)
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.log.exists())

    def test_generated_ownership_comment_is_stripped_from_body(self):
        path = self.data_dictionary_doc_path("generated.md")
        body = SYNC.GENERATED_OWNERSHIP_COMMENT.decode() + "\n\n# Doc title\n\nhello\n"
        path.write_text(f"---\nnotion-id: {PAGE}\nnotion-url: https://www.notion.so/workspace/{PAGE}\nnotion-sync: push\n---\n{body}")
        _page, _url, parsed_body, _resolved, _h1 = SYNC.parse_document(path, ROOT)
        self.assertNotIn(b"Generated by scripts/generate_data_dictionary.py", parsed_body)
        self.assertTrue(parsed_body.startswith(b"# Doc title"))

    def test_arbitrary_leading_comment_is_not_allowed(self):
        path = self.data_dictionary_doc_path("comment.md")
        path.write_text(f"---\nnotion-id: {PAGE}\nnotion-url: https://www.notion.so/workspace/{PAGE}\nnotion-sync: push\n---\n<!-- unrelated -->\n\n# Doc title\n\nhello\n")
        result = self.invoke(path)
        self.assertNotEqual(result.returncode, 0)

    def test_nested_traversal_and_symlink_are_rejected(self):
        path = self.data_dictionary_doc_path("allowed.md")
        path.write_text(f"---\nnotion-id: {PAGE}\nnotion-url: https://www.notion.so/workspace/{PAGE}\nnotion-sync: push\n---\n# Doc title\n\nhello\n")
        traversed = ROOT / "docs" / "data-dictionary" / ".." / "data-dictionary" / path.name
        self.assertNotEqual(self.invoke(traversed).returncode, 0)
        link = self.data_dictionary_doc_path("link.md")
        link.symlink_to(path)
        self.assertNotEqual(self.invoke(link).returncode, 0)


if __name__ == "__main__":
    unittest.main()
