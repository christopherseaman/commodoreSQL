#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "sync_notion_docs.py"
PAGE = "12345678-1234-1234-1234-123456789abc"


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="notion-sync-", dir=ROOT))
        self.docs = []
        self.log = self.tmp / "log.jsonl"
        self.fake = self.tmp / "fake-ntn"
        self.fake.write_text("""#!/usr/bin/env python3
import json, os, sys
log = os.environ['FAKE_LOG']
with open(log, 'a') as f: f.write(json.dumps({'argv': sys.argv[1:], 'keyring': os.environ.get('NOTION_KEYRING'), 'stdin': sys.stdin.buffer.read().decode()})+'\\n')
if sys.argv[1:3] == ['pages', 'get']:
 if os.environ.get('FAIL_GET_ID') and sys.argv[3].endswith('abd'):
  raise SystemExit(7)
 if os.environ.get('FAIL_VERIFY') and sum(1 for x in open(log) if '"get"' in x) > 1:
  print('{}')
 else:
  print(json.dumps({'page': {'id': sys.argv[3], 'parent': {'block_id': 'parent-1', 'type': 'page_id'}, 'properties': {'title': {'type': 'title', 'title': [{'plain_text': 'Doc title'}]}}}, 'markdown': {'id': sys.argv[3], 'object': 'page_markdown', 'request_id': 'req-1', 'truncated': bool(os.environ.get('TRUNCATED')), 'unknown_block_ids': ['block-1'] if os.environ.get('UNKNOWN') else [], 'markdown': '' if os.environ.get('EMPTY_PAGE') else '# Doc title\\n\\nmeaningful body'}}))
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

    def doc(self, name="doc.md", body="# Doc title\n\nhello\n"):
        path = self.root_doc_path(name)
        path.write_text(f"---\nnotion-id: {PAGE}\nnotion-url: https://www.notion.so/workspace/{PAGE}\nnotion-sync: push\n---\n{body}")
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
        self.assertEqual([e["argv"][:3] for e in entries], [["pages", "get", PAGE], ["pages", "edit", PAGE], ["pages", "get", PAGE]])
        self.assertEqual(entries[1]["stdin"], "# Doc title\n\nhello\n")
        self.assertEqual(entries[1]["keyring"], "0")

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
        self.assertTrue(any(e["argv"][1] == "edit" for e in self.entries()))

    def test_all_preflights_before_edit(self):
        one = self.doc("one.md")
        page2 = "12345678-1234-1234-1234-123456789abd"
        two = self.root_doc_path("two.md")
        two.write_text(self.doc("seed.md").read_text().replace(PAGE, page2))
        self.docs.append(two)
        self.env["FAIL_GET_ID"] = "1"
        result = self.invoke("--apply", one, two)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(e["argv"][1] == "edit" for e in self.entries()))

    def test_duplicate_file_and_page_are_rejected(self):
        one = self.doc("duplicate.md")
        self.assertNotEqual(self.invoke(one, one).returncode, 0)
        two = self.root_doc_path("duplicate-two.md")
        two.write_text(one.read_text())
        self.docs.append(two)
        self.assertNotEqual(self.invoke(one, two).returncode, 0)


if __name__ == "__main__":
    unittest.main()
