#!/bin/sh
# Build Groovelet.app into build/.
# Usage: scripts/app.sh [--debug]
# With --debug, the app has the debug links of src/ui/GLDebug.h.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP="$ROOT/build/Groovelet.app"
FFMPEG="$ROOT/build/ffmpeg"
if [ ! -f "$FFMPEG/lib/libglffmpeg.dylib" ]; then
    "$ROOT/scripts/ffmpeg.sh" >/dev/null
fi
DEBUG=""
if [ "$1" = "--debug" ]; then DEBUG="-DGL_DEBUG"; fi
rm -rf "$APP"
mkdir -p "$APP"

# shellcheck disable=SC2046
"$ROOT/build.sh" "$APP/Groovelet" $DEBUG -I"$ROOT/src/core" -I"$ROOT/src/audio" -I"$ROOT/src/ui" -I"$FFMPEG/include" \
    $(ls "$ROOT"/src/core/*.m "$ROOT"/src/audio/*.m "$ROOT"/src/ui/*.m 2>/dev/null) \
    "$FFMPEG/lib/libglffmpeg.dylib" -lsqlite3 \
    -framework Foundation -framework UIKit -framework CoreGraphics -framework QuartzCore \
    -framework MediaPlayer -framework AVFoundation -framework AudioToolbox -framework ImageIO \
    2>&1 | grep -v 'liblaunch.dylib' >&2 || true
[ -f "$APP/Groovelet" ]

cp "$FFMPEG/lib/libglffmpeg.dylib" "$APP/"
cp "$ROOT/resources/Info.plist" "$APP/Info.plist"
cp "$ROOT"/resources/*.png "$APP/" 2>/dev/null || true
cp "$ROOT"/resources/*.ttf "$APP/" 2>/dev/null || true
cp "$ROOT"/licenses/*.txt "$APP/"
printf 'APPL????' > "$APP/PkgInfo"
echo "$APP"
