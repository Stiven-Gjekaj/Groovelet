#!/usr/bin/env python3
# Make a large library of short MP3 files with ID3v2 tags, to measure the
# scan and the lists on the phone. The files hold one second of a tone.
# Usage: scripts/bigsamples.py COUNT OUT_DIRECTORY
import os
import random
import subprocess
import sys

count = int(sys.argv[1])
out = sys.argv[2]
tone = os.path.join(out, "tone.mp3")
os.makedirs(out, exist_ok=True)
subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i",
                "sine=frequency=440:duration=1", "-c:a", "libmp3lame", "-b:a", "64k", "-write_xing", "0",
                "-id3v2_version", "0", tone], check=True)
audio = open(tone, "rb").read()
os.remove(tone)


def frame(frame_id, text):
    body = b"\x03" + text.encode("utf-8")
    return frame_id.encode() + len(body).to_bytes(4, "big") + b"\x00\x00" + body


def syncsafe(n):
    return bytes([(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F])


random.seed(6)
words = ["Blue", "Night", "River", "Glass", "Echo", "Velvet", "Static", "Golden", "Paper", "Neon", "Silent",
         "Wild", "Lunar", "Copper", "Winter", "Electric", "Hollow", "Crystal", "Midnight", "Summer"]
tracks_per_album = 12
for i in range(count):
    album = i // tracks_per_album
    artist = album // 4
    artist_name = ("The " if artist % 5 == 0 else "") + words[artist % 20] + " " + words[(artist // 20) % 20] + \
        (" %d" % artist if artist >= 400 else "")
    album_name = words[album % 20] + " " + words[(album * 7) % 20] + " Vol. %d" % album
    title = " ".join(random.choice(words) for _ in range(random.randint(1, 3)))
    frames = frame("TIT2", title) + frame("TPE1", artist_name) + frame("TALB", album_name) + \
        frame("TRCK", str(i % tracks_per_album + 1)) + frame("TYER", str(1970 + album % 50))
    tag = b"ID3\x03\x00\x00" + syncsafe(len(frames)) + frames
    folder = os.path.join(out, artist_name, album_name)
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, "%02d %s.mp3" % (i % tracks_per_album + 1, title)), "wb") as f:
        f.write(tag + audio)
