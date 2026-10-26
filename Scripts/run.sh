#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-app.sh
open "$PWD/build/Vernier.app"
