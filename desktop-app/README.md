# Movie Album Sync — desktop app

A single-window app for syncing an album to a movie, for **Windows and Mac**. It's built for people who don't want to touch a terminal. ffmpeg is built in, so there's nothing else to install.

| Tab | What it does |
|-----|--------------|
| **Sync Album** | Puts the album onto the movie, starting a set number of seconds after (or before) the movie. **Preview** renders the first few minutes and plays them, so the timing can be checked before the full sync. **Format** is either *Best quality* (MKV with lossless FLAC audio) or *Plays everywhere* (MP4 with AAC audio, for TVs and phones). |
| **Combine Tracks** | Joins separate tracks into one album file. Drag tracks to reorder them. The result is added to the Sync Album tab automatically. |
| **Convert** | Converts a video to MP4/MKV/MOV, with a choice of video codec, size and audio format. |
| **File Info** | Shows a file's format, length and streams, and can save them as a text file. |
| **Settings** | Theme presets: System, Light and Dark, Pikachu, Charizard, Gengar, Bulbasaur, Grateful Dead, Slasher, Matrix, Synthwave, Tron, Sith, Jedi, Ocean, Sunset. Click any of the four color swatches to make a Custom theme. Also sets the text size, the font, and a sound when a job finishes. |

The app remembers the last timing, format, preview length, convert choices, folder and settings used.

---

## Downloads

Every version is published on the repo's **Releases** page:

| File | For |
|------|-----|
| `MovieAlbumSync-<version>-Setup.exe` | Windows (installer) |
| `MovieAlbumSync-<version>-Portable.zip` | Windows, no install needed |
| `MovieAlbumSync-<version>-Mac-AppleSilicon.dmg` | Macs with an M1–M4 chip (late 2020 and newer) |
| `MovieAlbumSync-<version>-Mac-Intel.dmg` | Older Intel Macs |

To check which Mac you have: Apple menu → **About This Mac** → **Chip** (Apple M-something) or **Processor** (Intel).

### Making a release

1. Bump `__version__` in `movie_album_sync/__init__.py` and commit.
2. Tag and push: `git tag v1.2.0`, then `git push origin v1.2.0`.
3. GitHub builds all three platforms in about 10 minutes, then publishes the Release with the downloads attached.

Every push that changes the app also runs the build (without publishing a release). The files are under the run's *Artifacts* on the **Actions** tab, which is handy for testing before tagging.

You can also build on your own computer: `.\build-windows.ps1` on Windows (needs Python 3 and Inno Setup 6), or `bash build-mac.sh` on a Mac (needs Python 3). The files appear in `dist/`.

### First-launch instructions to send along

Windows:

> 1. Download **MovieAlbumSync-Setup.exe** and open it.
> 2. If Windows says **"Windows protected your PC"**, click **More info → Run anyway**. That warning shows up because it's a homemade app, not something from a big company.
> 3. Click through the installer. A **Movie Album Sync** icon appears on your desktop.

Mac:

> 1. Download the **.dmg** for your Mac and open it. Drag **Movie Album Sync** onto the **Applications** folder.
> 2. Open it from Applications. The first time, macOS says it **can't verify the app**. Click **Done**, then go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Movie Album Sync. That's only needed once.

Then: choose the movie and the album, set when the album should start, and press **Preview** to check the timing. When it looks right, press **Sync Movie**.

---

## Development

Run from source:

```bash
python -m venv .venv
# Windows: .venv\Scripts\pip ...   Mac: .venv/bin/pip ...
pip install -r requirements.txt
# Put ffmpeg in desktop-app/ffmpeg/ (or have ffmpeg on PATH), then:
python -m movie_album_sync
```

Run the tests: `python -m unittest discover -s tests`

| File | Purpose |
|------|---------|
| `movie_album_sync/commands.py` | The ffmpeg commands for each tool (pure functions, unit-tested) |
| `movie_album_sync/ffmpeg.py` | Finds the bundled ffmpeg and runs jobs in the background with progress |
| `movie_album_sync/app.py` | The window and tabs |
| `movie_album_sync/themes.py` | Theme presets and palettes. Add a preset to `PRESET_GROUPS`, and `tests/test_themes.py` checks that it's readable. Give fonts as "Windows font, Mac font". |
| `build-windows.ps1` | Runs the tests, downloads ffmpeg, builds the app with PyInstaller, self-tests it, then makes the installer with Inno Setup |
| `build-mac.sh` | The same for Mac, ending with a `.dmg` |
| `installer.iss` | Inno Setup installer script |
| `make_icon.py` | Regenerates `assets/icon.ico` and `assets/icon.png` |

A packaged app can be checked with `--self-test`: it builds the window offscreen, runs the bundled ffmpeg, and exits 0 if everything works.

### Notes

- **Bundled ffmpeg:** Windows uses the "essentials" build from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/). Mac uses the release builds from [ffmpeg.martin-riedl.de](https://ffmpeg.martin-riedl.de/). Both include x264/x265, which are GPL-licensed, and the license ships inside the app. Sharing the app with friends is fine. If you distribute it widely, keep the source public and license the app under the GPL.
- **Security warnings:** the "Windows protected your PC" and "macOS can't verify this app" messages appear because the downloads aren't signed. Removing them costs money: a Windows code-signing certificate (e.g. Azure Trusted Signing, about $10/month), and Apple's Developer Program ($99/year) for Mac signing and notarization.
