#!/bin/sh
# Build Groovelet.app, copy it to the phone at "ssh iphone4s", and open it.
# Usage: scripts/install.sh [--debug]
# With --debug, the app has the debug links of src/ui/GLDebug.h.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/scripts/app.sh" "$@" >/dev/null

ssh iphone4s 'killall Groovelet >/dev/null 2>&1; rm -rf /Applications/Groovelet.app'
# The sftp server of the phone cannot make a new directory, so copy with tar.
# COPYFILE_DISABLE stops macOS tar from adding "._" files.
COPYFILE_DISABLE=1 tar --no-xattrs -C "$ROOT/build" -cf - Groovelet.app | ssh iphone4s 'tar -C /Applications -xf -'
# uicache must run as the mobile user, so that SpringBoard sees the new icon.
ssh iphone4s 'cd /Applications/Groovelet.app && for f in *.dylib; do [ -f "$f" ] && ldid -S "$f"; done; ldid -S Groovelet &&
    chown -R root:admin /Applications/Groovelet.app &&
    chmod 755 Groovelet &&
    su mobile -c uicache &&
    open io.github.stivengjekaj.groovelet'
