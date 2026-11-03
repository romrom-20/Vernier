#!/bin/bash
# Safe default while the owner uses the Mac: no visible windows, live capture or inference.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .context
output_dir="$(mktemp -d "$PWD/.context/background-checks.XXXXXX")"
printf 'Running isolated checks at reduced CPU priority. No foreground window tests or model calls.\n'
if ! /usr/bin/nice -n 10 ./Scripts/verify.sh > "$output_dir/verification.log" 2>&1; then
    tail -n 30 "$output_dir/verification.log"
    printf 'Check log: %s\n' "$output_dir/verification.log" >&2
    exit 1
fi
if ! /usr/bin/nice -n 10 build/Vernier.app/Contents/MacOS/Vernier --showcase --render-showcase "$output_dir" > "$output_dir/render.log" 2>&1; then
    cat "$output_dir/render.log"
    exit 1
fi
printf 'Background checks passed. Offscreen renders and logs: %s\n' "$output_dir"
printf 'Physical mouse, window focus and live ingestion are outside these checks.\n'
