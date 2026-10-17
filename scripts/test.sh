#!/bin/sh
# Build and run the tests.
# Usage: scripts/test.sh [--phone] [NAME]
# With no option, the tests of src/core operate on this Mac.
# With --phone, the tests of src/core and src/audio operate on the iPhone at
# "ssh iphone4s".
# NAME runs only the tests with NAME in their name.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/build/tests"
mkdir -p "$OUT"
CORE=$(ls "$ROOT"/src/core/*.m 2>/dev/null || true)
CORE_TESTS=$(ls "$ROOT"/tests/*.m "$ROOT"/tests/core/*.m 2>/dev/null || true)

if [ "$1" = "--phone" ]; then
    shift
    AUDIO=$(ls "$ROOT"/src/audio/*.m 2>/dev/null || true)
    AUDIO_TESTS=$(ls "$ROOT"/tests/audio/*.m 2>/dev/null || true)
    # shellcheck disable=SC2086
    "$ROOT/build.sh" "$OUT/gltests-armv7" -I"$ROOT/src/core" -I"$ROOT/src/audio" -I"$ROOT/tests" \
        $CORE $AUDIO $CORE_TESTS $AUDIO_TESTS -lsqlite3 \
        -framework Foundation -framework AudioToolbox -framework AVFoundation -framework CoreGraphics -framework ImageIO >"$OUT/build.log" 2>&1 ||
        { grep -v 'liblaunch.dylib' "$OUT/build.log" >&2; exit 1; }
    ssh iphone4s 'mkdir -p /tmp/gltests'
    scp -q "$OUT/gltests-armv7" iphone4s:/tmp/gltests/gltests
    ssh iphone4s "cd /tmp/gltests && ldid -S gltests && ./gltests $*"
else
    # shellcheck disable=SC2086
    clang -fobjc-arc -Wall -Werror -mmacosx-version-min=10.9 -I"$ROOT/src/core" -I"$ROOT/tests" \
        $CORE $CORE_TESTS -lsqlite3 -framework Foundation -framework CoreGraphics -framework ImageIO -o "$OUT/gltests"
    "$OUT/gltests" "$@"
fi
