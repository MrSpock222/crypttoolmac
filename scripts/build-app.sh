#!/bin/bash
# Builds the native Apple-Silicon CrypTool.app bundle into ./build/CrypTool.app
#
#   scripts/build-app.sh            # release build
#   CONFIG=debug scripts/build-app.sh
#   scripts/build-app.sh --dmg      # additionally create build/CrypTool.dmg
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CONFIG="${CONFIG:-release}"
SCRATCH="$ROOT/.build-$CONFIG"
APP="$ROOT/build/CrypTool.app"

echo "▸ Kompiliere CrypTool ($CONFIG, arm64) …"
swift build -c "$CONFIG" --arch arm64 --product CrypTool --scratch-path "$SCRATCH"
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --product CrypTool --scratch-path "$SCRATCH" --show-bin-path)"

echo "▸ Erzeuge App-Bundle …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CrypTool" "$APP/Contents/MacOS/CrypTool"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp -R "$ROOT/Resources/Reference" "$ROOT/Resources/Examples" "$ROOT/Resources/Words" "$ROOT/Resources/Help" "$ROOT/Resources/Images" "$ROOT/Resources/Docs" "$APP/Contents/Resources/"
[ -f "$ROOT/README.md" ] && cp "$ROOT/README.md" "$APP/Contents/Resources/README.md"
[ -f "$ROOT/LICENSE" ] && cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"

if [ ! -f "$ROOT/Resources/AppIcon.icns" ]; then
    echo "▸ Erzeuge App-Icon …"
    swift "$ROOT/scripts/make-icon.swift" "$ROOT/Resources"
fi
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Signiere (ad hoc) …"
codesign --force --deep --sign - "$APP"

echo "▸ Architektur: $(lipo -archs "$APP/Contents/MacOS/CrypTool")"
echo "✓ Fertig: $APP"

if [ "${1:-}" = "--dmg" ]; then
    DMG="$ROOT/build/CrypTool.dmg"
    rm -f "$DMG"
    STAGE="$(mktemp -d)"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "CrypTool" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
    rm -rf "$STAGE"
    echo "✓ Disk-Image: $DMG"
fi
