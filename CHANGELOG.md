# Changelog

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
