#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift test
swift build -c release --product Postigo
BIN="$(swift build -c release --show-bin-path)/Postigo"
"$BIN" --smoke
./scripts/make-icons.sh
./scripts/package.sh >/dev/null
test -x dist/Postigo.app/Contents/MacOS/Postigo
test -f dist/Postigo.app/Contents/Resources/AppIcon.icns
plutil -extract NSCameraUsageDescription raw dist/Postigo.app/Contents/Info.plist | grep -q Postigo
plutil -extract CFBundleDisplayName raw dist/Postigo.app/Contents/Info.plist | grep -q Postigo
plutil -extract CFBundleIdentifier raw dist/Postigo.app/Contents/Info.plist | grep -q br.com.designmaster.postigo
plutil -extract LSUIElement raw dist/Postigo.app/Contents/Info.plist | grep -q true
! grep -RIn --exclude-dir=.build --exclude-dir=dist --exclude-dir=.git --exclude=check.sh -I -E 'DeskCam|deskcam' .
echo "check ok"
