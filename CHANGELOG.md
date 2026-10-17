# Changelog

## 0.3.0 (2026-10-17)

- The app keeps an index of the music in SQLite, and scans the music
  directory at the start and when it comes back to the front.
- Five tabs: Artists, Albums, Songs, Playlists, and More. More holds Folders
  and Settings.
- The Albums tab is a grid of the art. An album page shows the tracks and a
  Play button.
- Each list has a search box, and the long lists have an index of letters.
- The app reads the tags of ID3, MP4, FLAC, Ogg, APE, WAV, and AIFF files,
  and the art in the file or in a cover image of the folder.
- A dark theme with the coral accent and the Inter font.
- With 10000 songs, the list of songs shows in 0.74 seconds after the launch.

## 0.2.0 (2026-10-17)

- The app plays FLAC, Opus, Ogg Vorbis, APE, and WavPack with an audio-only
  build of FFmpeg 7.1.
- Hi-res files and 5.1 files play as 44.1 kHz stereo.
- A seek in these formats goes to the exact frame.
- The CPU use during play is 1.5% to 6.2% of one core.

## 0.1.0 (2026-10-17)

- The app plays MP3, AAC, ALAC, WAV, and AIFF with the decoders of iOS.
- One AudioQueue plays the tracks, and the next track starts with no gap.
- The lock screen shows the track, and the remote controls and the buttons
  of the headphones work.
- Play pauses for a call and when the headphones come out.
- The music is in `/var/mobile/Media/Groovelet`. A computer copies files
  there over USB with an AFC tool.
- A plain list shows the audio files.
- `groovelet://` links play, pause, seek, and go to the next track.
