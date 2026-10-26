#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-app.sh
# Separate preferences, in-memory fixtures, no connector or personal archive.
exec build/Vernier.app/Contents/MacOS/Vernier --showcase
