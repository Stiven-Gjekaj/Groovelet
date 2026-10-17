# Groovelet

Groovelet is a music player for the iPhone 4S on iOS 6.1.3 (jailbroken).
It plays the audio files on the phone. It has a modern look, but it stays
light and fast on the A5 chip. You install it as a .deb package.

The decisions and their reasons are in [docs/decisions.md](docs/decisions.md).
The plan is in [TODO.md](TODO.md).

## Put music on the phone

The music is in `/var/mobile/Media/Groovelet`. Each folder and file there
shows in the app. The app plays MP3, AAC, ALAC, WAV, AIFF, FLAC, Opus, Ogg
Vorbis, APE, and WavPack.

- **Over USB:** connect the phone, and copy the files into `Groovelet` with
  an AFC tool, for example iFunBox, iMazing, 3uTools, or `afcclient` of
  libimobiledevice. iTunes File Sharing does not show an app in
  `/Applications`.
- **Over SSH:** `scp -r Album iphone4s:/var/mobile/Media/Groovelet/`

## Screens

- **Artists**, **Albums**, and **Songs** show the library. Albums is a grid
  of the art.
- **Playlists** shows the playlists.
- **More** holds Folders, which shows the files as they are on disk, and
  Settings.

Each list has a search box at the top. Pull the list down to see it.

A tap on the bar above the tabs opens the player. The player has shuffle,
repeat, the volume, AirPlay, and the queue. A long press on a track or an
album gives Play Next and Add to Queue.

The app reads the tags of the files. The art comes from the file, or from
an image named `cover`, `folder`, `front`, or `albumart` in the folder.

## Build

1. Download `iPhoneOS9.3.sdk.tar.xz` from the releases of
   <https://github.com/theos/sdks>.
2. Unpack it into `sdks/`. The result is `sdks/iPhoneOS9.3.sdk`.
3. Run the fix script one time:

       ./fix-sdk.sh

4. Build the app, install it on the phone at `ssh iphone4s`, and open it:

       scripts/install.sh

The SDK is third-party. Git does not track `sdks/`.

`build.sh` makes an armv7 binary in ARM mode for iOS 6. It compiles with ARC
and links without ARC.

## Scripts

| Script | What it does |
| --- | --- |
| `scripts/app.sh` | Builds `build/Groovelet.app`. |
| `scripts/install.sh` | Builds the app, copies it to the phone, and opens it. |
| `scripts/deb.sh` | Builds the Cydia package in `build/`. |
| `scripts/test.sh` | Runs the tests on the Mac. With `--phone`, it also runs the audio tests on the phone. |
| `scripts/samples.sh` | Makes sample music in each format and copies it to the phone. |
| `scripts/icons.sh` | Renders the icon and the launch images. |
| `scripts/ffmpeg.sh` | Builds the audio decoders of FFmpeg for the phone. `scripts/app.sh` runs it when necessary. |
| `scripts/fixtures.sh` | Makes the sound files of the FFmpeg tests. |
| `scripts/bigsamples.py` | Makes a library of many short files, to measure the speed. |

The phone is at `iphone4s` over a USB iproxy tunnel on port 2222.

## Links

Another app, or a shell on the phone with `uiopen`, controls the player:

    groovelet://play?path=Album/01%20Song.mp3&t=30
    groovelet://pause
    groovelet://resume
    groovelet://next
    groovelet://previous
    groovelet://seek?t=90
    groovelet://open?name=albums
    groovelet://open?name=album&path=Album/01%20Song.mp3
    groovelet://open?name=player
    groovelet://open?name=queue
