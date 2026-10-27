#!/usr/bin/env python3
"""Check tracked publication boundaries. Does not replace secret scanning or human review."""
import hashlib
import json
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
names = list(filter(None, subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")))
failures = []
manifest_path = root / ".github/public-images.json"
try:
    images = json.loads(manifest_path.read_text())["images"]
    if not isinstance(images, dict):
        raise ValueError("images must be a mapping")
except (OSError, ValueError, KeyError, TypeError):
    print("Publication hygiene failed: missing or invalid reviewed-image manifest")
    sys.exit(1)

private_parts = {".context", ".build", ".swiftpm", "build", ".codex", ".claude", "xcuserdata"}
private_names = {".ds_store", ".env", "auth.json", "credentials.json", "vernier-session-metadata.json"}
image_suffixes = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".icns", ".svg"}
reviewed = set()
for name in names:
    path = pathlib.PurePosixPath(name)
    parts = {part.lower() for part in path.parts}
    basename = path.name.lower()
    if (parts & private_parts or basename in private_names or basename.startswith(".env.") and basename != ".env.example"
            or any(part.endswith(".app") for part in parts)
            or path.suffix.lower() in {".pem", ".p12", ".key", ".log", ".jsonl", ".dmg", ".pkg"}
            or re.search(r"\.(?:sqlite3?|db)(?:-(?:wal|shm|journal))?$", basename)):
        failures.append(f"{name}: private/generated record, settings, export or key file")
    file = root / name
    if file.is_symlink():
        failures.append(f"{name}: symlink could expose files outside the reviewed source tree")
        continue
    if not file.is_file():
        continue
    data = file.read_bytes()
    if path.suffix.lower() in image_suffixes:
        entry = images.get(name, {})
        if (not isinstance(entry, dict) or entry.get("sha256") != hashlib.sha256(data).hexdigest()
                or not entry.get("provenance")):
            failures.append(f"{name}: image is new or changed; visually review synthetic provenance and update the manifest")
        reviewed.add(name)
        continue
    try:
        text = data.decode("utf-8")
        if "\0" in text:
            raise UnicodeDecodeError("utf-8", data, 0, 1, "binary NUL")
    except UnicodeDecodeError:
        failures.append(f"{name}: unreviewed binary file")
        continue
    for match in re.finditer(r"/(?:Users|home)/([A-Za-z0-9_.-]+)/", text):
        if match.group(1).lower() not in {"example", "test", "synthetic", "shared", "runner"}:
            failures.append(f"{name}: workstation-specific home path")
    if re.search(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s*\n[A-Za-z0-9+/]{30}", text):
        failures.append(f"{name}: possible private key payload")
for name in set(images) - reviewed:
    failures.append(f"{name}: image manifest entry has no tracked image")
if failures:
    print("Publication hygiene failed:\n" + "\n".join(sorted(set(failures))))
    sys.exit(1)
print(f"Publication hygiene passed ({len(names)} tracked paths; {len(reviewed)} reviewed image hashes). Secret scanning and human review remain separate.")
