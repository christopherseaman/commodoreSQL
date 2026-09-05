#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock
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
        self.fake.write_text("""#!/usr/bin/env python3
import json, os, sys
log = os.environ['FAKE_LOG']
state = log + '.state'
stdin = sys.stdin.buffer.read().decode()
with open(log, 'a') as f: f.write(json.dumps({'argv': sys.argv[1:], 'keyring': os.environ.get('NOTION_KEYRING'), 'stdin': stdin})+'\\n')
if sys.argv[1:2] == ['api']:
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
  open(state, 'w').write(request['replace_content']['new_str'])
  print(json.dumps({'object': 'page_markdown', 'id': sys.argv[2].split('/')[-2], 'markdown': request['replace_content']['new_str'], 'truncated': False, 'unknown_block_ids': []}))
 raise SystemExit(0)
if sys.argv[1:3] == ['pages', 'get']:
 if os.environ.get('FAIL_GET_ID') and sys.argv[3].endswith('abd'):
  raise SystemExit(7)
 if os.environ.get('FAIL_VERIFY') and sum(1 for x in open(log) if '"get"' in x) > 1:
  print('{}')
 else:
  markdown = '' if os.environ.get('EMPTY_PAGE') else ('# Doc title\\n\\n## Wrong\\nbody' if os.environ.get('MISMATCH_HEADINGS') else (open(state).read() if os.path.exists(state) else '# Doc title\\n\\nmeaningful body'))
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
        return subprocess.run(["python3", str(SCRIPT), "--ntn", str(self.fake), *map(str, args)], cwd="/", env=self.env, text=True, capture_output=True)

    def entries(self):
        return [json.loads(x) for x in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_check_does_not_write_and_strips_frontmatter(self):
        result = self.invoke(self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = self.entries()
        self.assertEqual([e["argv"][:3] for e in entries], [["pages", "get", PAGE]])
        self.assertEqual(entries[0]["keyring"], "0")

    def test_live_shape_empty_page_is_valid_for_check(self):
        self.env["EMPTY_PAGE"] = "1"
        result = self.invoke(self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_truncated_or_unknown_markdown_is_rejected(self):
        for variable in ("TRUNCATED", "UNKNOWN"):
            self.env[variable] = "1"
            self.assertNotEqual(self.invoke(self.doc()).returncode, 0)
            self.env.pop(variable)

    def test_apply_order_and_body(self):
        result = self.invoke("--apply", self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = self.entries()
        self.assertEqual([e["argv"][0] for e in entries], ["pages", "api", "pages"])
        request = json.loads(entries[1]["stdin"])
        self.assertIs(request["allow_async"], False)
        self.assertIn("replace_content", request)
        self.assertIn("hello", entries[1]["stdin"])
        self.assertEqual(entries[1]["keyring"], "0")

    def test_synchronous_success(self):
        result = self.invoke("--apply", self.doc())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_heading_mismatch_is_reported(self):
        self.env["MISMATCH_HEADINGS"] = "1"
        result = self.invoke("--apply", self.doc())
        self.assertIn("title, parent, or H1", result.stderr)

    def test_multiple_terminal_newlines_are_rejected(self):
        self.env["MULTI_TERMINAL_NEWLINE"] = "1"
        result = self.invoke("--apply", self.doc())
        self.assertNotEqual(result.returncode, 0)

    def test_submit_failure_includes_error(self):
        self.env["API_MODE"] = "submit-fail"
        result = self.invoke("--apply", self.doc())
        self.assertIn("too large", result.stderr)

    def test_malformed_response(self):
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
        self.env["FAIL_VERIFY"] = "1"
        result = self.invoke("--apply", self.doc())
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(e["argv"][0] == "api" for e in self.entries()))

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

    def test_manifest_is_explicit_and_has_45_entries(self):
        names = SYNC.load_manifest(Path("scripts/notion_sync_docs.txt"), ROOT)
        self.assertEqual(len(names), 45)
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(names[:8], [
            "CMM-DATA-FLOW.md", "SCHEMA.md", "CMM-ETL.md", "DATA-DICTIONARY.md", "DASHBOARDS-REPORTS.md",
            "COURSE-MATERIAL-POPULATIONS.md", "MAILING-FLOW.md", "PRICING-CATALOG-MATCHING.md",
        ])
        self.assertTrue(all(name.startswith("docs/data-dictionary/") for name in names[8:]))

    def test_direct_dictionary_child_is_allowed(self):
        path = self.data_dictionary_doc_path("allowed.md")
        path.write_text(f"---\nnotion-id: {PAGE}\nnotion-url: https://www.notion.so/workspace/{PAGE}\nnotion-sync: push\n---\n# Doc title\n\nhello\n")
        result = self.invoke(path)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_generated_ownership_comment_is_stripped_from_body(self):
        path = self.data_dictionary_doc_path("generated.md")
        body = SYNC.GENERATED_OWNERSHIP_COMMENT.decode() + "\n\n# Doc title\n\nhello\n"
        path.write_text(f"---\nnotion-id: {PAGE}\nnotion-url: https://www.notion.so/workspace/{PAGE}\nnotion-sync: push\n---\n{body}")
        result = self.invoke("--apply", path)
        self.assertEqual(result.returncode, 0, result.stderr)
        request = json.loads(self.entries()[1]["stdin"])
        self.assertNotIn("Generated by scripts/generate_data_dictionary.py", request["replace_content"]["new_str"])
        self.assertTrue(request["replace_content"]["new_str"].startswith("# Doc title"))

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
