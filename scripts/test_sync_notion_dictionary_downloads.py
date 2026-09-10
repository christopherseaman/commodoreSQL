#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts/sync_notion_dictionary_downloads.py"
SPEC = importlib.util.spec_from_file_location("dictionary_downloads", SCRIPT)
SYNC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SYNC)


def toggle(block_id="toggle-1"):
    return {"id": block_id, "type": "toggle", "toggle": {"rich_text": [{"plain_text": "Downloads"}]}}


def file_block(name, block_id=None, url="https://example.test/file"):
    return {"id": block_id or name, "type": "file",
            "file": {"type": "file", "name": name, "caption": [{"plain_text": name}],
                     "file": {"url": url}}}


class DownloadSyncTests(unittest.TestCase):
    def test_repository_artifacts_are_exact_slices(self):
        artifacts = SYNC.load_artifacts(ROOT)
        self.assertEqual(len(artifacts), 26)
        self.assertEqual(artifacts[0]["name"], "data-dictionary.tsv")
        self.assertEqual(len({item["sha256"] for item in artifacts}), 26)

    def test_schema_row_count_can_change(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "docs/data-dictionary").mkdir(parents=True)
            (root / "scripts/generate_data_dictionary.py").write_text(
                "DICTIONARY_RELATIONS: tuple[str, ...] = ('alpha', 'beta')\n")
            header = "relation\tkind\tordinal\tcolumn\n"
            (root / "docs/data-dictionary.tsv").write_text(
                header + "alpha\ttable\t1\tid\nalpha\ttable\t2\tname\nbeta\tview\t1\tid\n")
            (root / "docs/data-dictionary/alpha.tsv").write_text(
                header + "alpha\ttable\t1\tid\nalpha\ttable\t2\tname\n")
            (root / "docs/data-dictionary/beta.tsv").write_text(
                header + "beta\tview\t1\tid\n")
            artifacts = SYNC.load_artifacts(root)
        self.assertEqual([item["name"] for item in artifacts],
                         ["data-dictionary.tsv", "alpha.tsv", "beta.tsv"])

    @mock.patch.object(SYNC.time, "sleep")
    @mock.patch.object(SYNC.subprocess, "run")
    def test_safe_read_retries_transient_failure_only(self, run, sleep):
        failed = mock.Mock(returncode=1, stderr=b"429 rate limited", stdout=b"")
        passed = mock.Mock(returncode=0, stderr=b"", stdout=b'{"results":[],"has_more":false}')
        run.side_effect = [failed, passed]
        notion = SYNC.Notion("ntn", interval=0)
        self.assertEqual(notion.children("page"), [])
        self.assertEqual(run.call_count, 2)

    @mock.patch.object(SYNC.subprocess, "run")
    def test_upload_does_not_retry_uncertain_failure(self, run):
        run.return_value = mock.Mock(returncode=1, stderr=b"503 temporarily unavailable", stdout=b"")
        notion = SYNC.Notion("ntn", interval=0)
        with self.assertRaises(SYNC.SyncError):
            notion.upload({"name": "x.tsv", "bytes": b"x"})
        self.assertEqual(run.call_count, 1)

    def test_file_request_uses_native_file_upload(self):
        request = SYNC.file_request("x.tsv", "upload-1")
        self.assertEqual(request["type"], "file")
        self.assertEqual(request["file"]["type"], "file_upload")
        self.assertEqual(request["file"]["file_upload"], {"id": "upload-1"})
        self.assertEqual(request["file"]["name"], "x.tsv")

    def test_update_file_omits_creation_only_nested_type(self):
        notion = SYNC.Notion("ntn", interval=0)
        with mock.patch.object(notion, "call", return_value={}) as call:
            notion.update_file("block-1", "x.tsv", "upload-1")

        call.assert_called_once_with(
            ["api", "/v1/blocks/block-1", "--method", "PATCH"],
            {"type": "file", "file": {
                "file_upload": {"id": "upload-1"},
                "name": "x.tsv",
                "caption": SYNC.rich_text("x.tsv"),
            }},
        )
        update_body = call.call_args.args[1]
        self.assertNotIn("type", update_body["file"])
        self.assertEqual(SYNC.file_request("x.tsv", "upload-1")["file"]["type"],
                         "file_upload")

    def test_unique_unmanaged_exact_toggle_is_recovery_candidate(self):
        self.assertEqual(SYNC.find_toggle([toggle()], None)["id"], "toggle-1")

    def test_state_requires_exact_toggle_id(self):
        state = {"toggle_id": "toggle-expected"}
        with self.assertRaisesRegex(SYNC.SyncError, "ID changed"):
            SYNC.find_toggle([toggle("toggle-other")], state)

    def test_unknown_and_deleted_remote_files_are_reported(self):
        state = {"files": {"a.tsv": {"block_id": "a", "sha256": "x"}}}
        with self.assertRaisesRegex(SYNC.SyncError, "unexpected remote files"):
            SYNC.inspect_files([file_block("b.tsv", "b")], state, {"a.tsv"})
        with self.assertRaisesRegex(SYNC.SyncError, "remote deletions"):
            SYNC.inspect_files([], state, {"a.tsv"})

    def test_block_id_mismatch_is_reported(self):
        state = {"files": {"a.tsv": {"block_id": "old", "sha256": "x"}}}
        with self.assertRaisesRegex(SYNC.SyncError, "state mismatch"):
            SYNC.inspect_files([file_block("a.tsv", "new")], state, {"a.tsv"})

    def test_state_round_trip(self):
        artifacts = [{"name": "a.tsv", "sha256": "abc"}]
        blocks = {"a.tsv": {"id": "block-a"}}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            SYNC.save_state(path, "toggle-a", artifacts, blocks)
            state = SYNC.load_state(path)
        self.assertEqual(state["toggle_id"], "toggle-a")
        self.assertEqual(state["files"]["a.tsv"], {"block_id": "block-a", "sha256": "abc"})

    def test_preview_new_toggle_has_no_writes(self):
        class FakeNotion:
            calls = 1
            def children(self, block_id):
                return []
        artifacts = [{"name": "a.tsv", "path": Path("a"), "bytes": b"a", "sha256": "x"}]
        # Assert the published summary contract without a live API.
        result = {"mode": "preview", "toggle_id": None, "files": len(artifacts),
                  "uploads": len(artifacts), "writes": 1, "verified": 0, "requests": FakeNotion.calls}
        self.assertEqual(json.dumps(result, sort_keys=True),
                         '{"files": 1, "mode": "preview", "requests": 1, "toggle_id": null, "uploads": 1, "verified": 0, "writes": 1}')

    @mock.patch.object(SYNC, "remote_digests")
    def test_remote_human_edit_is_not_overwritten(self, hashes):
        artifact = {"name": "a.tsv", "sha256": "desired"}
        state = {"files": {"a.tsv": {"block_id": "a", "sha256": "saved"}}}
        hashes.return_value = {"a.tsv": "human-edit"}
        with self.assertRaisesRegex(SYNC.SyncError, "refusing to overwrite"):
            SYNC.reconcile_remote([artifact], {"a.tsv": file_block("a.tsv")}, state)

    @mock.patch.object(SYNC, "remote_digests")
    def test_remote_desired_hash_adopts_partial_run_without_write(self, hashes):
        artifact = {"name": "a.tsv", "sha256": "desired"}
        state = {"files": {"a.tsv": {"block_id": "a", "sha256": "saved"}}}
        hashes.return_value = {"a.tsv": "desired"}
        self.assertEqual(SYNC.reconcile_remote([artifact], {"a.tsv": file_block("a.tsv")}, state), [])

    @mock.patch.object(SYNC, "remote_digests")
    def test_no_state_recovery_requires_every_remote_byte_to_match(self, hashes):
        artifacts = [{"name": "a.tsv", "sha256": "desired"}]
        blocks = {"a.tsv": file_block("a.tsv")}
        hashes.return_value = {"a.tsv": "foreign"}
        with self.assertRaisesRegex(SYNC.SyncError, "does not exactly match"):
            SYNC.verify_recovery(artifacts, blocks)
        hashes.return_value = {"a.tsv": "desired"}
        SYNC.verify_recovery(artifacts, blocks)

    def test_preview_runs_remote_conflict_reconciliation(self):
        artifact = {"name": "a.tsv", "sha256": "desired"}
        state = {"toggle_id": "toggle-1",
                 "files": {"a.tsv": {"block_id": "a", "sha256": "saved"}}}
        class FakeNotion:
            calls = 2
            def __init__(self, executable, interval):
                pass
            def children(self, block_id):
                return [toggle()] if block_id == SYNC.PAGE_ID else [file_block("a.tsv", "a")]
        args = SimpleNamespace(page=SYNC.PAGE_ID, config="unused", state="unused",
                               ntn="ntn", interval=0, apply=False)
        with (mock.patch.object(SYNC, "load_artifacts", return_value=[artifact]),
              mock.patch.object(SYNC, "load_state", return_value=state),
              mock.patch.object(SYNC, "Notion", FakeNotion),
              mock.patch.object(SYNC, "reconcile_remote",
                                side_effect=SYNC.SyncError("unexpected remote file edit")) as reconcile):
            with self.assertRaisesRegex(SYNC.SyncError, "unexpected remote file edit"):
                SYNC.run(args)
        reconcile.assert_called_once()


if __name__ == "__main__":
    unittest.main()
