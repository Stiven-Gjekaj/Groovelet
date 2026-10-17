# Roadmap

Each release adds one big part. The risky audio work comes first. The reason
for each choice is in [docs/decisions.md](docs/decisions.md).

## 0.1: the audio engine (done, 2026-10-17)

- Copy the newer `build.sh` and `fix-sdk.sh` from ZettaLite.
- Copy the scripts, the packaging, and the test runner, with the prefix `GL`.
- Decode MP3, AAC, ALAC, WAV, and AIFF with the decoders of Apple.
- Play the sound through one audio output.
- Go from one file to the next with no gap.
- Show the track on the lock screen, and obey the remote controls.
- Show a plain list of the files in the music directory.

## 0.2: more formats (done, 2026-10-17)

- Build FFmpeg 7.1 LGPL for armv7 iOS 6, with only the audio decoders and
  demuxers.
- Play FLAC, Opus, Vorbis, APE, and WavPack in the same engine.
- Resample hi-res files to the rate of the output.

## 0.3: the library (done, 2026-10-17)

- Read the tags and the art.
- Keep the index in SQLite, and scan in the background.
- Add the five tabs, the dark theme, and the Inter font.

## 0.4: the player (done, 2026-10-17)

- Add the mini player and the now-playing screen.
- Add the queue, shuffle, and repeat.
- Resume the position and the queue after a restart.

## 0.5: getting files in (done, 2026-10-17)

- Add the Wi-Fi upload page.
- Add "Open in Groovelet".

## 0.6: playlists (done, 2026-10-17)

- Make and edit playlists in the app.
- Read M3U playlists.
- Keep the play counts, and add the three automatic playlists.

## 0.7: the last features (done, 2026-10-17)

- Add ReplayGain.
- Add the sleep timer.
- Delete tracks, albums, and folders.

## 1.0.0 (done, 2026-10-17)

- Check each feature and each target on the iPhone 4S with iOS 6.1.3.
- Add the icon and the brand.
- Build the .deb, and install it with `dpkg -i`.

## Next

- Publish the release on GitHub with the .deb, and add it to the Cydia
  repository. This waits for the owner.
- Upload `assets/brand/banner.png` as the social preview of the repository.

## Hand checks for the owner

The phone has no tool that makes a touch or a sound check. These checks
need a person:

- The buttons of the headphones, and the pause when they come out.
- A call during play, and the play after it.
- AirPlay.
- "Open in Groovelet" from Mail or Safari.
- The long press menus: Play Next, Add to Queue, Add to Playlist, Delete.
- New Playlist, Rename, and Change the Order.
- The sound of the gapless join in `Samples/Gapless`.

## Known problems

- APE files are not checked on the phone.
- A file that another app opens in Groovelet is not checked on the phone.
