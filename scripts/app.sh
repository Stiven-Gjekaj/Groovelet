#!/bin/sh
# Build Groovelet.app into build/.
# Usage: scripts/app.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP="$ROOT/build/Groovelet.app"
rm -rf "$APP"
mkdir -p "$APP"

# shellcheck disable=SC2046
"$ROOT/build.sh" "$APP/Groovelet" -I"$ROOT/src/core" -I"$ROOT/src/audio" -I"$ROOT/src/ui" \
    $(ls "$ROOT"/src/core/*.m "$ROOT"/src/audio/*.m "$ROOT"/src/ui/*.m 2>/dev/null) \
    -lsqlite3 \
    -framework Foundation -framework UIKit -framework CoreGraphics -framework QuartzCore \
    -framework MediaPlayer -framework AVFoundation -framework AudioToolbox -framework ImageIO \
    2>&1 | grep -v 'liblaunch.dylib' >&2 || true
[ -f "$APP/Groovelet" ]

cp "$ROOT/resources/Info.plist" "$APP/Info.plist"
cp "$ROOT"/resources/*.png "$APP/" 2>/dev/null || true
cp "$ROOT"/resources/*.ttf "$APP/" 2>/dev/null || true
printf 'APPL????' > "$APP/PkgInfo"
echo "$APP"
