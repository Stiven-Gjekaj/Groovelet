#!/bin/sh
# Make the small sound files of the FFmpeg tests into build/fixtures/.
# The decoders of iOS cannot write these formats, so the Mac makes them.
# ffmpeg has no APE encoder, so there is no APE file.
# Usage: scripts/fixtures.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/build/fixtures"
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$OUT"
F="ffmpeg -hide_banner -loglevel error -y"
S="sine=frequency=440:duration=2"

$F -f lavfi -i "$S:sample_rate=44100" -ac 2 -c:a flac flac-44100.flac
$F -f lavfi -i "$S:sample_rate=96000" -ac 2 -c:a flac -sample_fmt s32 flac-96000-24.flac
$F -f lavfi -i "$S:sample_rate=48000" -ac 1 -c:a libopus opus-48000-mono.opus
$F -f lavfi -i "$S:sample_rate=44100" -ac 2 -c:a vorbis -strict -2 vorbis-44100.ogg
$F -f lavfi -i "$S:sample_rate=44100" -ac 2 -c:a wavpack wavpack-44100.wv
$F -f lavfi -i "$S:sample_rate=48000" -ac 6 -c:a flac flac-51.flac
shasum "$ROOT/scripts/fixtures.sh" | cut -d" " -f1 > stamp
