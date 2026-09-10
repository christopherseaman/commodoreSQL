#!/usr/bin/env python3
import csv
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "sync_notion_dictionary.py"
SPEC = importlib.util.spec_from_file_location("sync_notion_dictionary", SCRIPT)
SYNC = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = SYNC
SPEC.loader.exec_module(SYNC)
DATA_SOURCE = "c987ec06-e8d3-4025-8f6e-49b0db2de150"


def values(column="id", relation="example", description="identifier"):
    return {
        "Column": column, "Table": relation, "Type": "bigint", "Upstream table": "source.id",
        "Derivation": "", "Sample values": "123", "Description": description, "NULL meaning": "never NULL",
        "Order": 1, "Kind": "table", "Key": f"{relation}::{column}",
    }


def api_properties(row):
    props = SYNC.notion_properties(row)
    result = {}
    for name, item in props.items():
        kind = SYNC.PROPERTY_TYPES[name]
        item["type"] = kind
        if kind in ("title", "rich_text"):
            for part in item[kind]:
                part["plain_text"] = part["text"]["content"]
        result[name] = item
    return result


class DictionarySyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="dictionary-sync-", dir=ROOT))
        self.tsv = self.tmp / "dictionary.tsv"
        self.state = self.tmp / "state.json"
        self.store = self.tmp / "remote.json"
        self.log = self.tmp / "calls.jsonl"
        self.schema = self.tmp / "schema.json"
        self.fake = self.tmp / "ntn"
        self.fake.write_text("""#!/usr/bin/env python3
import json, os, sys
store, log, schema_path = os.environ['FAKE_STORE'], os.environ['FAKE_LOG'], os.environ['FAKE_SCHEMA']
body = json.loads(sys.stdin.buffer.read() or b'{}')
with open(log, 'a') as f: f.write(json.dumps({'argv':sys.argv[1:], 'body':body, 'keyring':os.environ.get('NOTION_KEYRING')})+'\\n')
props = json.load(open(schema_path))
path, method = sys.argv[2], sys.argv[sys.argv.index('--method')+1]
rows = json.load(open(store)) if os.path.exists(store) else []
if path.startswith('/v1/data_sources/') and not path.endswith('/query'):
 if method == 'PATCH':
  for name, change in body['properties'].items():
   if 'name' in change:
    old = next(prop_name for prop_name, prop in props.items() if prop.get('id') == name)
    props[change['name']] = props.pop(old)
    for row in rows: row['properties'][change['name']] = row['properties'].pop(old)
   else:
    props[name] = {'type':next(iter(change))}
    for row in rows: row['properties'][name] = {'type':next(iter(change)), next(iter(change)):[]}
  json.dump(props,open(schema_path,'w'))
  json.dump(rows,open(store,'w'))
 print(json.dumps({'properties':props}))
elif path.endswith('/query'):
 print(json.dumps({'results':rows, 'has_more':False, 'next_cursor':None}))
elif path == '/v1/pages':
 page={'id':f'page-{len(rows)+1}', 'properties':body['properties']}; rows.append(page); json.dump(rows,open(store,'w')); print(json.dumps(page))
elif path.startswith('/v1/pages/'):
 page_id=path.rsplit('/',1)[1]
 page=next(x for x in rows if x['id']==page_id); page['properties'].update(body['properties']); json.dump(rows,open(store,'w')); print(json.dumps(page))
else: raise SystemExit(9)
""")
        self.fake.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(FAKE_STORE=str(self.store), FAKE_LOG=str(self.log), FAKE_SCHEMA=str(self.schema))
        self.write_schema()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write_tsv(self, rows=None):
        rows = rows or [["example", "table", "1", "id", "bigint", "source.id", "", "123", "identifier", "never NULL"]]
        with self.tsv.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
            writer.writerow(SYNC.HEADERS)
            writer.writerows(rows)

    def invoke(self, *extra):
        return subprocess.run([
            "python3", str(SCRIPT), "--ntn", str(self.fake), "--data-source", DATA_SOURCE,
            "--tsv", str(self.tsv), "--state", str(self.state), *extra,
        ], env=self.env, cwd="/", text=True, capture_output=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_tsv_contract_and_duplicate_validation(self):
        self.write_tsv()
        rows = SYNC.load_tsv(self.tsv)
        self.assertEqual(rows[0].key, "example::id")
        self.write_tsv([*[self.tsv_row()], *[self.tsv_row()]])
        with self.assertRaisesRegex(SYNC.SyncError, "duplicate key"):
            SYNC.load_tsv(self.tsv)

    @staticmethod
    def tsv_row():
        return ["example", "table", "1", "id", "bigint", "source.id", "", "123", "identifier", "never NULL"]

    def write_schema(self, legacy=False, derivation=True):
        names = dict(SYNC.PROPERTY_TYPES)
        if legacy:
            names["Direct upstream"] = names.pop("Upstream table")
            names["Example / format"] = names.pop("Sample values")
        if not derivation:
            names.pop("Derivation")
        self.schema.write_text(json.dumps({name: {"type": kind, "id": f"id-{index}"}
                                           for index, (name, kind) in enumerate(names.items())}))

    def test_wrong_headers_and_invalid_kind_are_rejected(self):
        self.tsv.write_text("relation\tkind\nexample\ttable\n")
        with self.assertRaisesRegex(SYNC.SyncError, "headers"):
            SYNC.load_tsv(self.tsv)
        self.write_tsv([["example", "materialized", "1", "id", "bigint", "", "", "", "", ""]])
        with self.assertRaisesRegex(SYNC.SyncError, "table or view"):
            SYNC.load_tsv(self.tsv)

    def test_long_rich_text_is_split_without_loss(self):
        content = "x" * 4501
        chunks = SYNC.rich_text(content)
        self.assertEqual([len(x["text"]["content"]) for x in chunks], [2000, 2000, 501])
        self.assertEqual("".join(x["text"]["content"] for x in chunks), content)

    def test_plan_adopts_exact_row_and_detects_remote_edit(self):
        local = SYNC.LocalRow("example::id", values())
        current = SYNC.RemoteRow("page-1", values())
        creates, updates, unchanged, problems = SYNC.plan([local], [current], {})
        self.assertEqual((creates, updates, unchanged, problems), ([], [], [current], []))
        edited = SYNC.RemoteRow("page-1", values(description="human edit"))
        state = {local.key: {"page_id": "page-1", "values": values()}}
        self.assertIn("changed since last sync", SYNC.plan([local], [edited], state)[3][0])

    def test_saved_row_missing_remotely_is_not_recreated(self):
        local = SYNC.LocalRow("example::id", values())
        state = {local.key: {"page_id": "page-1", "values": values()}}
        creates, _, _, problems = SYNC.plan([local], [], state)
        self.assertEqual(creates, [])
        self.assertIn("not recreated", problems[0])

    def test_mutations_disable_retries_and_update_checks_baseline(self):
        class Client:
            def __init__(self): self.calls = []
            def request(self, path, method="GET", body=None, **kwargs):
                self.calls.append((path, method, kwargs))
                if method == "GET": return {"properties": api_properties(values())}
                return {"id": "page-1"}
        client = Client()
        row = SYNC.LocalRow("example::id", values(description="new"))
        baseline = SYNC.RemoteRow("page-1", values())
        SYNC.apply_one(client, DATA_SOURCE, ("update", row, baseline))
        self.assertEqual(client.calls[0][:2], ("/v1/pages/page-1", "GET"))
        self.assertEqual(client.calls[1][2], {"retry_transient": False})

    def test_preview_is_read_only_and_forces_file_auth(self):
        self.write_tsv()
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("create=1", result.stdout)
        calls = self.calls()
        self.assertEqual([x["argv"][1] for x in calls], [f"/v1/data_sources/{DATA_SOURCE}", f"/v1/data_sources/{DATA_SOURCE}/query"])
        self.assertTrue(all(x["keyring"] == "0" for x in calls))
        self.assertFalse(self.store.exists())

    def test_apply_readback_state_and_unchanged_second_run(self):
        self.write_tsv()
        applied = self.invoke("--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertIn("verified=1 writes=1", applied.stdout)
        saved = json.loads(self.state.read_text())
        self.assertEqual(saved["records"]["example::id"]["values"], values())
        call_count = len(self.calls())
        preview = self.invoke()
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertIn("create=0 update=0 unchanged=1", preview.stdout)
        second_calls = self.calls()[call_count:]
        self.assertFalse(any(x["argv"][1] == "/v1/pages" for x in second_calls))

    def test_schema_mismatch_stops_before_query(self):
        self.write_tsv()
        # Unit-level malformed schema makes the preflight behavior deterministic.
        class Client:
            def request(self, path, method="GET", body=None):
                return {"properties": {}}
        with self.assertRaisesRegex(SYNC.SyncError, "schema mismatch"):
            SYNC.validate_schema(Client(), DATA_SOURCE)

    def test_config_supplies_default_data_source(self):
        config = self.tmp / "config.json"
        config.write_text(json.dumps({"data_source_id": DATA_SOURCE}))
        self.assertEqual(SYNC.configured_data_source(config), DATA_SOURCE)

    def seed_legacy(self, *, description="identifier", partial=False):
        current = values(description=description)
        legacy = {name: value for name, value in current.items()
                  if name not in ("Upstream table", "Derivation", "Sample values")}
        legacy["Direct upstream"] = current["Upstream table"]
        legacy["Example / format"] = current["Sample values"]
        props = api_properties(current)
        props["Direct upstream"] = props.pop("Upstream table")
        if partial:
            props["Sample values"] = props.pop("Sample values")
        else:
            props["Example / format"] = props.pop("Sample values")
        props.pop("Derivation")
        self.store.write_text(json.dumps([{"id": "page-1", "properties": props}]))
        self.state.write_text(json.dumps({"version": 1, "data_source_id": DATA_SOURCE,
                                          "records": {"example::id": {"page_id": "page-1", "values": legacy}}}))

    def test_field_schema_migration_preview_and_apply_preserve_ids(self):
        self.write_schema(legacy=True, derivation=False)
        old_schema = json.loads(self.schema.read_text())
        self.seed_legacy()
        preview = self.invoke("--migrate-field-schema")
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertIn("schema_changes=3 state_changes=1 issues=0", preview.stdout)
        self.assertIn("Direct upstream", self.schema.read_text())
        applied = self.invoke("--migrate-field-schema", "--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        saved = json.loads(self.state.read_text())["records"]["example::id"]
        self.assertEqual(saved["page_id"], "page-1")
        self.assertEqual(saved["values"], values())
        schema = json.loads(self.schema.read_text())
        self.assertEqual(schema["Upstream table"]["id"], old_schema["Direct upstream"]["id"])
        self.assertEqual(schema["Sample values"]["id"], old_schema["Example / format"]["id"])

    def test_field_schema_migration_blocks_remote_edit(self):
        self.write_schema(legacy=True, derivation=False)
        self.seed_legacy(description="human edit")
        state = json.loads(self.state.read_text())
        state["records"]["example::id"]["values"]["Description"] = "identifier"
        self.state.write_text(json.dumps(state))
        result = self.invoke("--migrate-field-schema", "--apply")
        self.assertEqual(result.returncode, 2)
        self.assertIn("changed since last sync", result.stderr)
        self.assertIn("Direct upstream", self.schema.read_text())

    def test_field_schema_migration_recovers_interrupted_rename(self):
        self.write_schema(legacy=True, derivation=False)
        schema = json.loads(self.schema.read_text())
        schema["Sample values"] = schema.pop("Example / format")
        self.schema.write_text(json.dumps(schema))
        self.seed_legacy(partial=True)
        result = self.invoke("--migrate-field-schema", "--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("schema_changes=2", result.stdout)
        self.assertEqual(json.loads(self.state.read_text())["records"]["example::id"]["values"], values())


if __name__ == "__main__":
    unittest.main()
