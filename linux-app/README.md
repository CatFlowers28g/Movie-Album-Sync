# Unified FFmpeg Toolkit — Linux

The Linux version of the toolkit. It has the same five tools as the Mac app:

- Movie Sync Audio
- FFmpeg Info Logger
- FLAC Combiner
- Test Clip Extractor
- Transcode Final Product

It is a bash script that uses `zenity` dialogs and runs ffmpeg in your terminal emulator.

## Setup

1. Install the dependencies:
   ```bash
   # Debian / Ubuntu / Mint
   sudo apt install ffmpeg zenity
   # Fedora (ffmpeg comes from RPM Fusion)
   sudo dnf install ffmpeg zenity
   # Arch
   sudo pacman -S ffmpeg zenity
   ```
2. Add the toolkit to your app menu:
   ```bash
   bash install.sh
   ```
   This copies the script to `~/.local/bin/unified-ffmpeg-toolkit` and adds a **Unified FFmpeg Toolkit** entry to your desktop's app menu. Run it again after updating the script.

## Usage

- Open **Unified FFmpeg Toolkit** from your app menu, or run `bash unified-ffmpeg-toolkit.sh` from this folder.
- Choose a tool and follow the dialogs.
- A terminal window opens and shows ffmpeg's progress. It stays open when ffmpeg finishes so you can check for errors. Press `Ctrl+C` in it to stop a job.

The script tries these terminals in order: `$TERMINAL`, `x-terminal-emulator`, `gnome-terminal`, `ptyxis`, `kgx`, `konsole`, `xfce4-terminal`, `mate-terminal`, `tilix`, `kitty`, `alacritty`, `xterm`. To force a specific one, set `TERMINAL` (for example `export TERMINAL=konsole`).

## Differences from the Mac app

- The output filename and folder are picked in one **Save** dialog instead of two prompts.
- ffmpeg runs with `-y` (overwrite), because the Save dialog already asks before replacing a file.
- **FLAC Combiner** sorts the selected files by name (so `Track 2` comes before `Track 10`), and shows the order before combining.

## Files

- `unified-ffmpeg-toolkit.sh`: the toolkit itself.
- `install.sh`: installs it to `~/.local/bin` and the app menu.
