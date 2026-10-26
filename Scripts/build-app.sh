#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-debug}"
swift build -c "$configuration" --product Vernier
bin_path="$(swift build -c "$configuration" --show-bin-path)"
app_path="$PWD/build/Vernier.app"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/Vernier" "$app_path/Contents/MacOS/Vernier"
cp Sources/VernierApp/Resources/Brand.plist "$app_path/Contents/Resources/Brand.plist"
if [ ! -f build/Vernier.icns ] || [ Scripts/make-icon.swift -nt build/Vernier.icns ]; then
    swift Scripts/make-icon.swift "$PWD/build/Vernier.iconset"
    iconutil -c icns build/Vernier.iconset -o build/Vernier.icns
fi
cp build/Vernier.icns "$app_path/Contents/Resources/Vernier.icns"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
# Local integrity only. Ad-hoc signing is NOT Developer ID signing or notarization.
codesign --force --sign - "$app_path"
printf 'Local development app: %s\n' "$app_path"
