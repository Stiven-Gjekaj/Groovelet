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
    FFMPEG="$ROOT/build/ffmpeg"
    if [ ! -f "$FFMPEG/lib/libglffmpeg.dylib" ]; then
        "$ROOT/scripts/ffmpeg.sh" >/dev/null
    fi
    AUDIO=$(ls "$ROOT"/src/audio/*.m 2>/dev/null || true)
    AUDIO_TESTS=$(ls "$ROOT"/tests/audio/*.m 2>/dev/null || true)
    # shellcheck disable=SC2086
    "$ROOT/build.sh" "$OUT/gltests-armv7" -I"$ROOT/src/core" -I"$ROOT/src/audio" -I"$ROOT/tests" -I"$FFMPEG/include" \
        $CORE $AUDIO $CORE_TESTS $AUDIO_TESTS "$FFMPEG/lib/libglffmpeg.dylib" -lsqlite3 \
        -framework Foundation -framework AudioToolbox -framework AVFoundation -framework CoreGraphics -framework ImageIO >"$OUT/build.log" 2>&1 ||
        { grep -v 'liblaunch.dylib' "$OUT/build.log" >&2; exit 1; }
    ssh iphone4s 'mkdir -p /tmp/gltests'
    scp -q "$OUT/gltests-armv7" iphone4s:/tmp/gltests/gltests
    scp -q "$FFMPEG/lib/libglffmpeg.dylib" iphone4s:/tmp/gltests/
    # Make the fixtures again and copy them again when scripts/fixtures.sh changes.
    STAMP=$(shasum "$ROOT/scripts/fixtures.sh" | cut -d" " -f1)
    if [ "$(cat "$ROOT/build/fixtures/stamp" 2>/dev/null)" != "$STAMP" ]; then
        "$ROOT/scripts/fixtures.sh" >/dev/null
    fi
    if [ "$(ssh iphone4s 'cat /tmp/gltests/fixtures/stamp 2>/dev/null')" != "$STAMP" ]; then
        ssh iphone4s 'rm -rf /tmp/gltests/fixtures'
        # The sftp server of the phone cannot make a new directory, so copy with tar.
        COPYFILE_DISABLE=1 tar --no-xattrs -C "$ROOT/build" -cf - fixtures | ssh iphone4s 'tar -C /tmp/gltests -xf - 2>/dev/null'
    fi
    ssh iphone4s "cd /tmp/gltests && ldid -S libglffmpeg.dylib && ldid -S gltests && ./gltests $*"
else
    # shellcheck disable=SC2086
    clang -fobjc-arc -Wall -Werror -mmacosx-version-min=10.9 -I"$ROOT/src/core" -I"$ROOT/tests" \
        $CORE $CORE_TESTS -lsqlite3 -framework Foundation -framework CoreGraphics -framework ImageIO -o "$OUT/gltests"
    "$OUT/gltests" "$@"
fi
