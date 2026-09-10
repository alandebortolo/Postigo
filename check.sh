#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift test
swift build -c release --product DeskCam
BIN="$(swift build -c release --show-bin-path)/DeskCam"
"$BIN" --smoke
./scripts/package.sh >/dev/null
test -x dist/DeskCam.app/Contents/MacOS/DeskCam
plutil -extract NSCameraUsageDescription raw dist/DeskCam.app/Contents/Info.plist >/dev/null
plutil -extract LSUIElement raw dist/DeskCam.app/Contents/Info.plist | grep -q true
echo "check ok"
