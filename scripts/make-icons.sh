#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Resources/icon-source.jpg"
PNG="$ROOT/Resources/AppIcon-1024.png"
SET="$ROOT/Resources/AppIcon.iconset"
ICNS="$ROOT/Resources/AppIcon.icns"

sips -s format png -z 1024 1024 "$SRC" --out "$PNG" >/dev/null
rm -rf "$SET"
mkdir -p "$SET"
sips -z 16 16     "$PNG" --out "$SET/icon_16x16.png" >/dev/null
sips -z 32 32     "$PNG" --out "$SET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$PNG" --out "$SET/icon_32x32.png" >/dev/null
sips -z 64 64     "$PNG" --out "$SET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$PNG" --out "$SET/icon_128x128.png" >/dev/null
sips -z 256 256   "$PNG" --out "$SET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$PNG" --out "$SET/icon_256x256.png" >/dev/null
sips -z 512 512   "$PNG" --out "$SET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$PNG" --out "$SET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$PNG" --out "$SET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$SET" -o "$ICNS"
rm -rf "$SET"
echo "$ICNS"
