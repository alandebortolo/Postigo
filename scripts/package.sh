#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --product Postigo
BIN="$(swift build -c release --show-bin-path)/Postigo"
DIST="$ROOT/dist/Postigo.app"

rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp "$BIN" "$DIST/Contents/MacOS/Postigo"
cp "$ROOT/Resources/Info.plist" "$DIST/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$DIST/Contents/Resources/AppIcon.icns"
printf 'APPLPSTG' > "$DIST/Contents/PkgInfo"
chmod +x "$DIST/Contents/MacOS/Postigo"

codesign --force --sign - --identifier br.com.designmaster.postigo "$DIST" >/dev/null

echo "$DIST"
