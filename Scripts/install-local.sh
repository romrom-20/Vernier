#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-app.sh
apps_dir="$HOME/Applications"
destination="$apps_dir/Vernier.app"
mkdir -p "$apps_dir" .context
staging="$(mktemp -d "$apps_dir/.Vernier-stage.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto build/Vernier.app "$staging/Vernier.app"
codesign --verify --deep --strict "$staging/Vernier.app"
if [ -e "$destination" ]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$destination/Contents/Info.plist")"
    if [ "$existing_id" != "local.vernier.instrument.dev" ]; then
        printf 'Refusing to replace an unrelated application at %s\n' "$destination" >&2
        exit 1
    fi
    backup_dir="$(mktemp -d "$PWD/.context/previous-install.XXXXXX")"
    mv "$destination" "$backup_dir/Vernier.app"
    if ! mv "$staging/Vernier.app" "$destination"; then
        mv "$backup_dir/Vernier.app" "$destination"
        exit 1
    fi
    printf 'Previous local build kept at %s\n' "$backup_dir/Vernier.app"
else
    mv "$staging/Vernier.app" "$destination"
fi
printf 'Installed local development app: %s\nOpen it from Finder, Spotlight, or: open "%s"\n' "$destination" "$destination"
