#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --product DeskCam
BIN="$(swift build -c release --show-bin-path)/DeskCam"
DIST="$ROOT/dist/DeskCam.app"

rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp "$BIN" "$DIST/Contents/MacOS/DeskCam"
cp "$ROOT/Resources/Info.plist" "$DIST/Contents/Info.plist"
printf 'APPLDSCM' > "$DIST/Contents/PkgInfo"
chmod +x "$DIST/Contents/MacOS/DeskCam"

codesign --force --sign - --identifier br.com.designmaster.deskcam "$DIST" >/dev/null

echo "$DIST"
