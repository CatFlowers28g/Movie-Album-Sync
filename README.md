# Movie-Album-Sync

A point-and-click toolkit for syncing an album to a movie with ffmpeg, plus helpers for combining tracks, converting video, and inspecting media.

| Platform | Folder | How to get it |
|----------|--------|---------------|
| **Windows** | [desktop-app/](desktop-app/) | **Movie Album Sync** desktop app. Install it with `MovieAlbumSync-Setup.exe`; ffmpeg is built in. |
| macOS    | [applescript-apps/](applescript-apps/) | AppleScript app: run `bash compile-apps.sh`, then open `Unified FFmpeg Toolkit.app`. |
| Linux    | [linux-app/](linux-app/) | zenity-based script: run `bash install.sh`, then open it from the app menu. |

The desktop app is written in Python + Qt, so it can be built for Mac and Linux later. Once those builds exist, they will replace the two script versions.

See [desktop-app/README.md](desktop-app/README.md) for how to build the installer and share it.

## Tools

- **Sync Album**: puts an album onto a movie with an adjustable offset. A negative offset starts the album before the movie, with a black screen filling the gap. Preview renders the first few minutes so you can check the timing.
- **Combine Tracks**: joins separate tracks into one continuous album file.
- **Convert**: converts to MP4/MKV/MOV with a choice of codec and resolution.
- **File Info**: shows a file's streams and codecs, and saves them as a text log.

## Keeping versions in sync

The ffmpeg commands are duplicated in each version. When you change an ffmpeg option (for example the sync filter or encoder settings), update all of these:

- `desktop-app/movie_album_sync/commands.py` (then run its tests: `python -m unittest discover -s tests`)
- `applescript-apps/00-Unified-FFmpeg-Toolkit.applescript`
- `linux-app/unified-ffmpeg-toolkit.sh`
