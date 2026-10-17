# Decisions

This file records each choice of the owner and each technical decision.
Each entry gives the reason. The owner made these choices on 2026-10-17.

## What the app is

- **Groovelet is a music player for the iPhone 4S on iOS 6.1.3.**
  It plays the audio files that the app keeps on the phone. It is a native
  Objective-C app with ARC, installed as a .deb package on a jailbroken
  phone.
- **The app plays only its own files.** It does not read the iPod library
  of iTunes. Files that the app owns are the reason for a player on a
  jailbroken phone: they can be in any format, and no sync is necessary.
- **The app does not use the network**, except for the Wi-Fi upload page on
  the local network. It reads no online metadata and does no scrobbling.
- **The repository is public.** The licence is MIT.

## Identity

- Bundle ID `io.github.stivengjekaj.groovelet`, display name `Groovelet`.
- iPhone only. iOS 6.0 or later. Portrait only.
- URL scheme `groovelet://`, for later use.

## Integration with the system

- Play continues when the screen locks (`UIBackgroundModes` audio).
- The lock screen and the multitasking bar show the title, the artist, and
  the art, with play, pause, next, and previous (`MPNowPlayingInfoCenter`
  and remote control events).
- The buttons of the headphones work.
- AirPlay audio works.
- Play pauses for a call or for Siri, and starts again after it.
- Play stops when the headphones come out.

## How files get onto the phone

- **iTunes File Sharing** (`UIFileSharingEnabled`).
- **A Wi-Fi upload page.** The app runs a small HTTP server that serves one
  page. A browser on the same network drops files and folders on it.
  - The server runs only while the Upload screen is open. The screen stays
    on.
  - The screen shows `http://<ip>:<port>`.
  - The page has no password. It is open only on the local network, and
    only while the owner watches the screen.
  - The page cannot download or delete files.
  - The index scans the new files when the upload ends.
- **"Open in Groovelet"** from Mail, Safari, and other apps
  (`CFBundleDocumentTypes`).
- Files that scp copies into `Documents/` also work.
- **No download from a URL.** It needs the TLS of mbedTLS, because the TLS
  of iOS 6 fails with many servers. ZettaLite shows this.

## Formats

- **MP3, AAC (M4A), ALAC, WAV, and AIFF use the decoders of Apple.** The
  AAC path uses the hardware, so it saves the battery.
- **FLAC, Opus, Ogg Vorbis, APE, and WavPack use FFmpeg.** The build is
  FFmpeg 7.1, LGPL only, with only the audio decoders and demuxers. It ships
  as a dylib inside the app, so that the MIT licence of the app stays clean.
- **Hi-res files are resampled** to the rate of the output.
- **Both decoders feed one audio output**, so all formats act the same.
  Gapless play and ReplayGain need this. The app cannot use `AVPlayer` for
  this reason.

## Playback

Version 1.0 has these features:

- a queue with "play next" and "add to queue"
- shuffle, repeat all, and repeat one
- gapless play between tracks
- ReplayGain from the tags, for each track or for each album
- resume of the position and the queue after a restart
- a sleep timer

**These features are never built:** an equalizer, crossfade, play speed,
lyrics, and scrobbling.

## The library

- The app reads the tags from ID3, MP4 atoms, and Vorbis comments.
- The art comes from the art in the file, or from `cover.jpg` or
  `folder.jpg` in the folder of the track. The app does not get art online.
- The index is in SQLite (`libsqlite3` is on iOS 6). A fast scan compares
  the size and the date of each file. The scan runs in the background.
- **Group and sort rules:**
  - Artists group by the album artist, then by the artist. So a "Various
    Artists" compilation stays one album.
  - The sort ignores "The " and "A ", and uses the sort tags when a file has
    them.
  - Albums of one artist sort by year.
  - Tracks sort by disc, then by track number.
  - A file with no tags uses its folder as the album and its file name as
    the title.
  - The app does not read CUE sheets.

## Playlists

- The owner makes playlists in the app. A playlist can get tracks, lose
  tracks, and change its order.
- The app reads `.m3u` and `.m3u8` files in Documents as playlists that
  cannot change.
- Three playlists are automatic: Recently Added, Most Played, and Recently
  Played. The index keeps a play count and the date of the last play of
  each track.

## File management

- The app deletes a track, an album, or a folder from the phone, after a
  confirmation.
- The app does not edit tags, rename files, or move files. A computer does
  that.

## The interface

- **A dark theme on the stock iOS 6 bars.** The bars have a tint. The app
  bundles the Inter font with `UIAppFonts`.
- **The colors:** the accent is coral `#FF6B4A`, and the background is
  `#111111`. They are different from the green of Spotify and the red of
  Apple Music.
- **Five tabs:** Artists, Albums, Songs, Playlists, and More. More holds
  Folders, Upload, and Settings.
- **A mini player** sits above the tab bar. A tap on it opens the full
  now-playing screen.
- **Each list has a search box** at the top.
- **The now-playing screen:**
  - large art, then the title, the artist, and the album
  - a scrubber with the elapsed time and the time left
  - previous, play or pause, and next
  - an `MPVolumeView` with the AirPlay route button
  - shuffle, repeat, the queue (with reorder by drag), and the sleep timer
  - a blurred and dark copy of the art as the background. The app makes it
    one time for each album and keeps it on disk, because a live blur is
    too slow on the A5 chip.
- **Drawing:** the views use `CALayer`, not `drawRect`, so that the lists
  scroll fast.
- **Settings:** ReplayGain (Off, Track, or Album, with Track as the
  default), rescan the library, the sort that ignores "The" (on), the
  Folders tab (on), and About with the version, the licences, and a link to
  GitHub. Nothing more.

## The brand

- The logo is a small vinyl or groove mark. The owner picks it from SVG
  drafts.
- The icon has its own round corners and gloss. iOS 6 does not add them for
  an app in `/Applications`, because it takes that app for a system app.
  RetroTube found this.
- `assets/cover.svg` is the art for a track with no art.

## Targets for speed and size

These are measured on the iPhone 4S with the tools in `probe/`.

- The library holds 10,000 tracks.
- A cold start shows the last screen in less than 1 second, before the scan.
- The lists scroll at 60 frames per second.
- The art thumbnails are made at the size of the cell and kept on disk.
- During play, the CPU use is less than 5% for MP3 and AAC, and less than
  10% for FLAC.

## Toolchain

- The app builds with the iOS 9.3 SDK of Theos and the clang of the current
  Xcode, as RetroTube and ZettaLite do.
- `build.sh` and `fix-sdk.sh` come from ZettaLite in their newer form:
  - `-I` and `-D` options
  - objects in `build/obj`
  - `-Werror=unguarded-availability`
  - the C string functions in the libsystem_c stub
- All code is ARM mode (`-marm`). The new Apple linker makes Thumb code that
  crashes on iOS 6 before `main` starts.
- The scripts, the packaging, and the test runner come from ZettaLite with
  the prefix `GL`. Each app stays self-contained.

## Process

- Commit subjects start with `feat:`, `fix:`, `docs:`, `chore:`, `build:`,
  `refactor:`, or `test:`. The first 4 commits have no prefix. They stay as
  they are, because the history is public.
- Releases are 0.x versions up to 1.0.0. Each release gets a tag `vX.Y.Z`,
  notes in `CHANGELOG.md`, and the .deb as an asset on GitHub. Then the
  package goes into the Cydia repository `Stiven-Gjekaj/cydia`.
- On iOS 6, a person installs the .deb with `dpkg -i`. The APT of Cydia on
  iOS 6 supports TLS 1.0 only, and GitHub Pages accepts only TLS 1.2.
