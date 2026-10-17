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

- **The music is in `/var/mobile/Media/Groovelet`** (decided during 0.1,
  2026-10-17). The app is in `/Applications`, so iOS runs it as a system
  app with the home directory `/var/mobile`. All such apps share
  `/var/mobile/Documents`. Another app already keeps a video there.
  `/var/mobile/Media` is the root of AFC, the file service of iOS over USB.
- **USB copy with an AFC tool replaces iTunes File Sharing.** A test on the
  iPhone 4S (2026-10-17) showed that iTunes File Sharing cannot reach an app
  in `/Applications`: the house_arrest service of iOS answers
  `InstallationLookupFailed`, also for ZettaLite, which has
  `UIFileSharingEnabled`. Plain AFC shows `Media/Groovelet` with no
  jailbreak tool. iFunBox, iMazing, 3uTools, and `afcclient` of
  libimobiledevice copy files there.
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
- Files that scp copies into `/var/mobile/Media/Groovelet` also work.
- **No download from a URL.** It needs the TLS of mbedTLS, because the TLS
  of iOS 6 fails with many servers. ZettaLite shows this.

## Formats

- **MP3, AAC (M4A), ALAC, WAV, and AIFF use the decoders of Apple.** The
  AAC path uses the hardware, so it saves the battery.
- **FLAC, Opus, Ogg Vorbis, APE, and WavPack use FFmpeg.** The build is
  FFmpeg 7.1, LGPL only, with only the audio decoders and demuxers. It ships
  as a dylib inside the app, so that the MIT licence of the app stays clean.
- **Hi-res files are resampled** to the rate of the output.
- **The FFmpeg build holds only audio** (0.2, 2026-10-17). It has the
  demuxers flac, ogg, ape, wv, and matroska, the decoders flac, opus, vorbis,
  ape, and wavpack, and libswresample. The dylib is 1.6 MB. It has no
  network and no zlib. `scripts/ffmpeg.sh` keeps the fix of the `movrelx`
  macro from ZettaLite, because the new Apple linker stops without it.
- **A seek in FFmpeg is exact.** The demuxer lands on a packet before the
  target. The decoder drops the frames before the target.
- **Both decoders feed one audio output**, so all formats act the same.
  Gapless play and ReplayGain need this. The app cannot use `AVPlayer` for
  this reason.

## Playback

- **One AudioQueue plays all tracks.** `GLRenderer` reads the decoders and
  fills the buffers of the queue. When a track ends inside a buffer, the next
  track starts in the same buffer. The renderer counts the frames, and the
  time of the queue tells which track plays now.
- **4 buffers of 8192 frames** (0.74 seconds). A larger buffer wakes the CPU
  less often. A seek makes a new queue and fills it at once.
- **The decoders of Apple drop the priming frames and the padding of AAC.**
  A test on the iPhone 4S (2026-10-17) decoded 3 seconds of AAC from
  ExtAudioFile as exactly 132300 frames.

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

- **The app reads the tags with its own reader, `GLTags`** (0.3). It reads
  ID3v2 (2.2 to 2.4), ID3v1, MP4 atoms, Vorbis comments in FLAC and Ogg,
  APEv2, and the chunks of WAV and AIFF. It seeks past the bytes of a
  picture during a scan. A scan that read the art of 10000 files would read
  gigabytes on the flash of the phone. FFmpeg could read the tags, but only
  for its own formats, and a file opens slower.
- **The duration comes from the decoder.** The scan opens each new file with
  the decoder that plays it. A first scan of 10000 short MP3 files on the
  iPhone 4S took 103 seconds (2026-10-17). A scan with no change took 7
  seconds. It walks the directory and compares the size and the date.
- **Covering indexes make the long lists fast** (0.3). With 10000 tracks on
  the iPhone 4S (2026-10-17):

  | Query | Before | After |
  | --- | --- | --- |
  | All songs, by title | 1.19 s | 0.34 s |
  | The grid of the albums | 0.56 s | 0.14 s |
  | The top folder | 0.73 s | 0.24 s |

  SQLite sorted the songs in a temporary table. An index that holds all the
  columns of the list gives the rows in order. The list of songs reads only
  the columns that it shows. The folder reads only the paths, and then the
  full rows of the files in the folder.
- **The start time** with 10000 tracks (2026-10-17): the full list of songs
  shows 0.74 seconds after the launch of the app. iOS takes 0.58 seconds more
  to start the process.
- **The art of an album changes with its files.** The scan gives the keys of
  the albums that it changed. The art cache removes their copies, and makes
  them again when a list asks.

## Playlists

- The owner makes playlists in the app. A playlist can get tracks, lose
  tracks, and change its order.
- The app reads `.m3u` and `.m3u8` files in the music directory as playlists that
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

## Measured speed

`probe/cpu.m` measured the CPU use on the iPhone 4S during play
(2026-10-17). The value is the share of one core, over 8 seconds.

| File | Groovelet | mediaserverd |
| --- | --- | --- |
| MP3, 192 kbit/s | 2.1% | 6.3% |
| AAC, 128 kbit/s | 1.6% | 6.3% |
| FLAC, 44.1 kHz | 1.5% | 6.3% |
| FLAC, 96 kHz, 24-bit | 5.3% | 6.3% |
| Opus, 48 kHz | 6.2% | 6.2% |

The targets were less than 5% for MP3 and AAC, and less than 10% for FLAC.
mediaserverd mixes the sound for all apps. Its share does not change with
the format. The resampler causes the most cost, for 96 kHz and for the
48 kHz of Opus.

On iOS 6, `proc_pidinfo` gives the CPU time in Mach ticks, not in
nanoseconds. A busy loop showed 2.4% before the probe changed the ticks
into seconds.

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
