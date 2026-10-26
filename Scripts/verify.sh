#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift run VernierCoreChecks
if [[ "$(xcode-select -p)" == *Xcode* ]]; then
    swift test
else
    printf 'XCTest skipped: full Xcode is not selected; shared core checks ran above.\n'
fi
./Scripts/build-app.sh
plutil -lint Resources/Info.plist Sources/VernierApp/Resources/Brand.plist
codesign --verify --deep --strict build/Vernier.app
if [ "${1:-}" = "--ui" ]; then
    # Requires a logged-in graphical Mac session, not a headless CI runner.
    build/Vernier.app/Contents/MacOS/Vernier --smoke-test
fi
