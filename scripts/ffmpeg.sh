#!/bin/sh
# Build the audio part of FFmpeg for armv7 iOS 6 into build/ffmpeg/.
# The result is one dylib, libglffmpeg.dylib, and the headers. It holds only
# the decoders and the demuxers of the formats that iOS does not read:
# FLAC, Opus, Vorbis, APE, and WavPack. It also holds the resampler.
# FFmpeg is LGPL. The build has no --enable-gpl and no --enable-nonfree.
# Usage: scripts/ffmpeg.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SDK="$ROOT/sdks/iPhoneOS9.3.sdk"
VERSION=7.1.1
SHA256=733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1
DL="$ROOT/build/dl"
SRC="$ROOT/build/ffmpeg-src/ffmpeg-$VERSION"
OUT="$ROOT/build/ffmpeg"

mkdir -p "$DL"
TARBALL="$DL/ffmpeg-$VERSION.tar.xz"
if [ ! -f "$TARBALL" ]; then
    curl -sSfL "https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.xz" -o "$TARBALL"
fi
echo "$SHA256  $TARBALL" | shasum -a 256 -c - >/dev/null

if [ ! -d "$SRC" ]; then
    mkdir -p "$ROOT/build/ffmpeg-src"
    tar -C "$ROOT/build/ffmpeg-src" -xf "$TARBALL"
fi

# The movrelx macro puts a pointer in the non-lazy pointer section with the
# label ".Lpic". On Darwin, only an "L" label is local. The new Apple linker
# stops with an assertion when a pointer in that section has a name.
sed -i '' 's/ldpic           \\rd, \.Lpic\\@, indir=1/ldpic           \\rd, Lnlp\\@, indir=1/;' \
    "$SRC/libavutil/arm/asm.S"
perl -0pi -e 's/(\.non_lazy_symbol_pointer\n)\.Lpic\\@:/$1Lnlp\\@:/' "$SRC/libavutil/arm/asm.S"

TARGET="-target armv7-apple-ios6.0 -isysroot $SDK -Wno-incompatible-sysroot"
STAGE="$ROOT/build/ffmpeg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cd "$STAGE"

"$SRC/configure" \
    --prefix="$STAGE/install" \
    --enable-cross-compile --target-os=darwin --arch=arm --cpu=cortex-a9 \
    --cc="clang" --as="clang" \
    --extra-cflags="$TARGET -marm -mfpu=neon" \
    --extra-ldflags="$TARGET" \
    --enable-static --disable-shared --enable-pic \
    --disable-programs --disable-doc --disable-debug \
    --disable-everything \
    --disable-avdevice --disable-avfilter --disable-postproc --disable-swscale \
    --enable-avcodec --enable-avformat --enable-swresample \
    --enable-protocol=file \
    --enable-demuxer=flac,ogg,ape,wv,matroska \
    --enable-decoder=flac,opus,vorbis,ape,wavpack \
    --enable-parser=flac,opus,vorbis \
    --disable-videotoolbox --disable-audiotoolbox --disable-securetransport \
    --disable-sdl2 --disable-xlib --disable-bzlib --disable-lzma --disable-zlib \
    --disable-iconv --disable-hwaccels --disable-devices --disable-filters \
    --disable-network >"$STAGE/configure.log" 2>&1 ||
    { tail -30 "$STAGE/configure.log"; exit 1; }

# The 9.3 SDK has functions that iOS 6 does not have. configure finds them
# and FFmpeg then calls them. Turn them off.
for name in CLOCK_GETTIME; do
    sed -i '' "s/^#define HAVE_$name 1/#define HAVE_$name 0/" config.h
done

make -j"$(sysctl -n hw.ncpu)" >"$STAGE/make.log" 2>&1 || { grep -m 20 -B2 -A5 'error' "$STAGE/make.log"; exit 1; }
make install >/dev/null

# Join the static libraries into one dylib. The app loads it from its bundle.
rm -rf "$OUT"
mkdir -p "$OUT/lib"
cp -R "$STAGE/install/include" "$OUT/include"
L="$STAGE/install/lib"
clang $TARGET -marm -Os -c "$ROOT/src/ffmpeg/builtins.c" -o "$STAGE/builtins.o"
clang $TARGET -dynamiclib -marm "$STAGE/builtins.o" \
    -install_name @executable_path/libglffmpeg.dylib \
    -Wl,-all_load "$L/libavformat.a" "$L/libavcodec.a" "$L/libswresample.a" "$L/libavutil.a" \
    -framework CoreFoundation -framework Foundation \
    -o "$OUT/lib/libglffmpeg.dylib"
echo "$OUT/lib/libglffmpeg.dylib"
