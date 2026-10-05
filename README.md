# Movie-Album-Sync

A point-and-click toolkit for syncing an album to a movie with ffmpeg, plus helpers for combining tracks, converting video, and inspecting media.

| Platform | Folder | How to get it |
|----------|--------|---------------|
| **Windows** | [desktop-app/](desktop-app/) | **Movie Album Sync** desktop app: `MovieAlbumSync-Setup.exe` from [Releases](../../releases). ffmpeg is built in. |
| **macOS** | [desktop-app/](desktop-app/) | **Movie Album Sync** desktop app: the `.dmg` for your Mac's chip (Apple Silicon or Intel) from [Releases](../../releases). |
| macOS (older) | [applescript-apps/](applescript-apps/) | The original AppleScript app: run `bash compile-apps.sh`, then open `Unified FFmpeg Toolkit.app`. Kept until the desktop app has been tested on Mac. |
| Linux    | [linux-app/](linux-app/) | zenity-based script: run `bash install.sh`, then open it from the app menu. |

The desktop app is written in Python + Qt. A Linux build of it could replace the Linux script later.

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
