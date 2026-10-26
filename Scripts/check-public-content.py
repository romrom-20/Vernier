#!/usr/bin/env python3
"""Publication hygiene for tracked content, not a comprehensive secret detector."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
names = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
failures = []
for name in filter(None, names):
    path = pathlib.PurePosixPath(name)
    if path.parts[0] in {".context", ".build", "build"} or path.suffix.lower() in {".sqlite", ".sqlite3", ".db", ".pem", ".p12", ".key"}:
        failures.append(f"{name}: private/generated record or key file")
    file = root / name
    if not file.is_file():
        continue
    try:
        text = file.read_text()
    except UnicodeDecodeError:
        continue  # Images require separate visual review using synthetic data.
    for match in re.finditer(r"/Users/([A-Za-z0-9_.-]+)/", text):
        if match.group(1).lower() not in {"example", "test", "synthetic", "shared", "runner"}:
            failures.append(f"{name}: workstation-specific home path")
    if re.search(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s*\n[A-Za-z0-9+/]{30}", text):
        failures.append(f"{name}: possible private key payload")
if failures:
    print("Publication hygiene failed:\n" + "\n".join(sorted(set(failures))))
    sys.exit(1)
print(f"Publication hygiene passed ({sum(bool(n) for n in names)} tracked paths). Images and secrets require separate review.")
