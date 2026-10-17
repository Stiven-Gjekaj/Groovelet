#!/bin/sh
# Make a small library of sample music and copy it to the phone at
# "ssh iphone4s", into Media/Groovelet/Samples. The files have tags, and
# each format of the app is there, except APE, because ffmpeg has no APE
# encoder. The sounds are tones from ffmpeg.
# Usage: scripts/samples.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/build/samples/Samples"
rm -rf "$OUT"
mkdir -p "$OUT"
F="ffmpeg -hide_banner -loglevel error -y"

# make FILE SECONDS FREQUENCY TITLE ARTIST ALBUM TRACK [OPTIONS]
make() {
    file=$1 seconds=$2 frequency=$3 title=$4 artist=$5 album=$6 track=$7
    shift 7
    $F -f lavfi -i "sine=frequency=$frequency:sample_rate=44100:duration=$seconds" -ac 2 \
        -metadata title="$title" -metadata artist="$artist" -metadata album_artist="$artist" \
        -metadata album="$album" -metadata track="$track" -metadata date=2026 "$@" "$OUT/$file"
}

mkdir -p "$OUT/Tones" "$OUT/Formats" "$OUT/Gapless"
make "Tones/01 Low.mp3" 20 220 "Low" "The Tones" "First Tones" 1 -c:a libmp3lame -b:a 192k
make "Tones/02 Middle.mp3" 20 440 "Middle" "The Tones" "First Tones" 2 -c:a libmp3lame -b:a 192k
make "Tones/03 High.mp3" 20 880 "High" "The Tones" "First Tones" 3 -c:a libmp3lame -b:a 192k
make "Formats/AAC.m4a" 15 330 "AAC" "Format Band" "Formats" 1 -c:a aac -b:a 128k
make "Formats/ALAC.m4a" 15 350 "ALAC" "Format Band" "Formats" 2 -c:a alac
make "Formats/WAV.wav" 15 370 "WAV" "Format Band" "Formats" 3
make "Formats/AIFF.aiff" 15 390 "AIFF" "Format Band" "Formats" 4
make "Formats/FLAC.flac" 15 410 "FLAC" "Format Band" "Formats" 5 -c:a flac
make "Formats/Opus.opus" 15 430 "Opus" "Format Band" "Formats" 6 -c:a libopus -ar 48000
make "Formats/Vorbis.ogg" 15 450 "Vorbis" "Format Band" "Formats" 7 -c:a vorbis -strict -2 -ac 2
make "Formats/WavPack.wv" 15 470 "WavPack" "Format Band" "Formats" 8 -c:a wavpack
make "Formats/HiRes.flac" 15 490 "Hi-Res" "Format Band" "Formats" 9 -c:a flac -ar 96000 -sample_fmt s32

# One sweep cut into two files. With gapless play, the sweep has no break.
$F -f lavfi -i "aevalsrc=sin(2*PI*(200+40*t)*t):s=44100:d=20" -ac 2 "$OUT/Gapless/sweep.wav"
$F -i "$OUT/Gapless/sweep.wav" -t 10 -metadata title="Sweep 1" -metadata artist="Gapless" \
    -metadata album="Gapless" -metadata track=1 -c:a flac "$OUT/Gapless/1 Sweep.flac"
$F -ss 10 -i "$OUT/Gapless/sweep.wav" -metadata title="Sweep 2" -metadata artist="Gapless" \
    -metadata album="Gapless" -metadata track=2 -c:a flac "$OUT/Gapless/2 Sweep.flac"
rm "$OUT/Gapless/sweep.wav"

ssh iphone4s 'rm -rf /var/mobile/Media/Groovelet/Samples && mkdir -p /var/mobile/Media/Groovelet'
COPYFILE_DISABLE=1 tar --no-xattrs -C "$ROOT/build/samples" -cf - Samples |
    ssh iphone4s 'tar -C /var/mobile/Media/Groovelet -xf - && chown -R mobile:mobile /var/mobile/Media/Groovelet'
echo "$OUT"
