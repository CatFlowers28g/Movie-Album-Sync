# Movie Album Sync — desktop app

A single-window app for syncing an album to a movie. It's built for people who don't want to touch a terminal. ffmpeg is built in, so there's nothing else to install.

| Tab | What it does |
|-----|--------------|
| **Sync Album** | Puts the album onto the movie, starting a set number of seconds after (or before) the movie. **Preview** renders the first few minutes and plays them, so the timing can be checked before the full sync. **Format** is either *Best quality* (MKV with lossless FLAC audio) or *Plays everywhere* (MP4 with AAC audio, for TVs and phones). |
| **Combine Tracks** | Joins separate tracks into one album file. Drag tracks to reorder them. The result is added to the Sync Album tab automatically. |
| **Convert** | Converts a video to MP4/MKV/MOV, with a choice of video codec, size and audio format. |
| **File Info** | Shows a file's format, length and streams, and can save them as a text file. |
| **Settings** | Theme presets: System, Light and Dark, Pikachu, Charizard, Gengar, Bulbasaur, Grateful Dead, Slasher, Matrix, Synthwave, Tron, Sith, Jedi, Ocean, Sunset. Click any of the four color swatches to make a Custom theme. Also sets the text size, the font, and a sound when a job finishes. |

The app remembers the last timing, format, preview length, convert choices, folder and settings used.

---

## Sharing it with someone

Send them the **installer**: `MovieAlbumSync-<version>-Setup.exe` (about 70 MB).

To get the installer, use either option:
- **On GitHub (no setup needed):** open the repo's **Actions** tab → **Build Windows app** → **Run workflow**. When the run finishes, download **MovieAlbumSync-Windows** from the run's *Artifacts* section.
  - To get a permanent download link instead, push a version tag and the files are attached to a GitHub Release: `git tag v1.0.0`, then `git push origin v1.0.0`. Send your friend the release page link.
- **On your own PC:** run `.\build-windows.ps1` in PowerShell from this folder. The files appear in `dist\`.

### Instructions to send along

> 1. Download **MovieAlbumSync-Setup.exe** and open it.
> 2. Windows may show **"Windows protected your PC"**. This happens because the app isn't from a big company. Click **More info → Run anyway**.
> 3. Click through the installer. A **Movie Album Sync** icon appears on your desktop.
> 4. Open it, choose the movie and the album, set when the album should start, and press **Preview** to check the timing. When it looks right, press **Sync Movie**.

There's also a `Portable.zip` that runs without installing: unzip it, then open `MovieAlbumSync.exe` inside. The installer is simpler for most people.

---

## Development

Run from source:

```powershell
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
# Put ffmpeg.exe in desktop-app\ffmpeg\ (or have ffmpeg on PATH), then:
.venv\Scripts\python -m movie_album_sync
```

Run the tests: `python -m unittest discover -s tests`

| File | Purpose |
|------|---------|
| `movie_album_sync/commands.py` | The ffmpeg commands for each tool (pure functions, unit-tested) |
| `movie_album_sync/ffmpeg.py` | Finds the bundled ffmpeg and runs jobs in the background with progress |
| `movie_album_sync/app.py` | The window and tabs |
| `movie_album_sync/themes.py` | Theme presets and palettes. Add a preset to `PRESET_GROUPS`, and `tests/test_themes.py` checks that it's readable. |
| `build-windows.ps1` | Runs the tests, downloads ffmpeg, builds the app with PyInstaller, then makes the installer with Inno Setup |
| `installer.iss` | Inno Setup installer script |
| `make_icon.py` | Regenerates `assets/icon.ico` |

To release a new version, bump `__version__` in `movie_album_sync/__init__.py`, then build or tag.

### Notes

- **Bundled ffmpeg:** the build uses the "essentials" build from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/). It includes x264/x265, which are GPL-licensed, and its license ships with the app (`_internal\ffmpeg\LICENSE.txt`). Sharing the app with friends is fine. If you distribute it widely, keep the source public and license the app under the GPL.
- **"Windows protected your PC":** this warning appears because the installer isn't code-signed. Removing it requires a code-signing certificate, for example Azure Trusted Signing at about $10/month.
