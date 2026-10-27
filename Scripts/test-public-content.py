#!/usr/bin/env python3
"""Exercise publication failures in disposable Git indexes, without personal files or commits."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest

SOURCE = pathlib.Path(__file__).resolve().parent.parent


class PublicationChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="vernier-publication-check-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True, capture_output=True)
        (self.root / "Scripts").mkdir()
        shutil.copyfile(SOURCE / "Scripts/check-public-content.py", self.root / "Scripts/check-public-content.py")
        (self.root / ".github").mkdir()
        (self.root / "Docs/images").mkdir(parents=True)
        image = (SOURCE / "Docs/images/overview.png").read_bytes()
        self.write("Docs/images/example.png", image)
        self.write(".github/public-images.json", json.dumps({"images": {"Docs/images/example.png": {
            "sha256": hashlib.sha256(image).hexdigest(), "provenance": "Reviewed synthetic fixture"
        }}}).encode())

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def check(self):
        subprocess.run(["git", "add", "-f", "."], cwd=self.root, check=True, capture_output=True)
        return subprocess.run(["python3", "Scripts/check-public-content.py"], cwd=self.root, text=True, capture_output=True)

    def test_reviewed_source_passes(self):
        self.assertEqual(self.check().returncode, 0)

    def test_private_records_are_rejected_even_if_force_added(self):
        for name in [".context/notes.txt", "nested/.codex/auth.json", "archive.sqlite-wal", "archive.db-shm",
                     "Vernier-session-metadata.json", ".env.local", "debug.log", "rollout.jsonl"]:
            with self.subTest(name=name):
                self.write(name, b"Invented test content, never a personal record.")
                result = self.check()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(name, result.stdout)

    def test_changed_image_requires_review(self):
        with (self.root / "Docs/images/example.png").open("ab") as handle:
            handle.write(b"changed fixture")
        self.assertIn("image is new or changed", self.check().stdout)

    def test_unlisted_image_requires_review(self):
        self.write("Docs/images/unreviewed.png", b"Invented image placeholder")
        self.assertIn("unreviewed.png: image is new or changed", self.check().stdout)

    def test_unreviewed_binary_is_rejected(self):
        self.write("unknown.bin", b"\0synthetic")
        self.assertIn("unreviewed binary", self.check().stdout)

    def test_local_home_path_is_rejected(self):
        self.write("example.txt", ("/Users/" + "private-machine" + "/project").encode())
        self.assertIn("workstation-specific home path", self.check().stdout)

    def test_symlink_is_rejected(self):
        (self.root / "external.txt").symlink_to("/nonexistent/synthetic")
        self.assertIn("symlink", self.check().stdout)

    def test_generic_example_home_is_allowed(self):
        self.write("example.txt", b"/Users/example/conductor/workspaces/repo/workspace")
        self.assertEqual(self.check().returncode, 0)


if __name__ == "__main__":
    unittest.main()
