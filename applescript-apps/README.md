# FFmpeg AppleScript Toolkit

One unified macOS app for all ffmpeg workflows in this folder. The source now builds a single app that contains the following tools:

- Movie Sync Audio
- FFmpeg Info Logger
- FLAC Combiner
- Test Clip Extractor
- Transcode Final Product

## Unified App

### **Unified FFmpeg Toolkit**
A single AppleScript toolkit that merges all workflow logic into one app. Choose the tool you need from a menu and follow the prompts.

**Features:**
- Sync audio to video with adjustable delay
- Generate ffmpeg analysis logs
- Combine multiple FLAC audio tracks
- Extract synced test clips
- Transcode final output to different containers, codecs, and resolutions

**Output:** User-selected output files produced through ffmpeg, with progress shown in Terminal.

## Installation & Usage

### Quick Start

1. **The app is already compiled and located at:**
   ```
   ~/Applications/Unified FFmpeg Toolkit.app
   ```

2. **To run the app:**
   - Open Finder → Applications (or ~/Applications)
   - Double-click `Unified FFmpeg Toolkit.app`
   - Choose the tool you need from the menu
   - Follow the dialog prompts to select files and parameters
   - Terminal window opens automatically to show progress

3. **If you need to recompile the app:**
   ```bash
   cd /path/to/applescript-apps
   bash compile-apps.sh
   ```
   This will recompile the unified app and place it in `~/Applications`

---

## Recommended Workflow

### For syncing audio to video (like album to film):

1. **First, create an FFmpeg Log** to inspect your files
   - Open `Unified FFmpeg Toolkit.app`
   - Choose `FFmpeg Info Logger`
   - Select your video or audio file
   - Review the generated `.txt` log to confirm codecs and streams

2. **Test with a short clip** to verify sync timing
   - Choose `Test Clip Extractor`
   - Extract the first few minutes with your desired audio delay
   - Watch the clip to confirm audio/video sync

3. **Extract and combine audio if needed**
   - Choose `FLAC Combiner` if you have separate FLAC tracks
   - Merge individual tracks into one continuous file

4. **Create the final synced video**
   - Choose `Movie Sync Audio`
   - Use the same audio delay you validated in step 2
   - Process the full-length video and audio

---

## Technical Details

### Audio Delay Parameter
- Measured in **milliseconds** (1000ms = 1 second)
- Default: 36000ms = 36 seconds
- Adjustments needed if:
  - Audio starts too early: **increase** delay
  - Audio starts too late: **decrease** delay
  - Or use negative values: `-36000` (note the minus sign)

### File Compatibility

**Video Input:**
- MKV (Matroska Video)
- MP4 (MPEG-4)
- Other ffmpeg-compatible formats

**Audio Input:**
- FLAC (Free Lossless Audio Codec) - recommended for quality
- MP3 (MPEG-3)
- Other ffmpeg-compatible formats

**Audio Output:**
- FLAC (lossless, for Movie Sync Audio)
- Original codec preserved in Info Logger

### Why Terminal Window Opens
The apps intentionally show Terminal window during processing so you can:
- Monitor ffmpeg's real-time progress
- See encoding speed and ETA
- Catch any errors or warnings immediately
- Stop the process if needed (Ctrl+C)

---

## Troubleshooting

### App won't open?
- Ensure ffmpeg is installed: `ffmpeg -version` in Terminal
- Grant execution permissions: `chmod +x` on the script files

### File dialogs not responding?
- Try again, macOS dialogs sometimes have slight delays
- Restart the app if needed

### ffmpeg command fails?
- Check the error message in Terminal window
- Verify input files exist and are readable
- Confirm file formats are supported by ffmpeg

### Need to adjust audio delay?
1. Run **Test Clip Extractor** with different delay values
2. Watch the test output to find the correct delay
3. Use that same value in **Movie Sync Audio**

---

## Source Files

The AppleScript source code is available in this directory:
- `00-Unified-FFmpeg-Toolkit.applescript`

You can edit this file and recompile using `compile-apps.sh` if you need to customize behavior or commands.

---

## Notes

- All apps require **ffmpeg** to be installed and available in PATH
- Output files are created in the location you specify via dialog
- Terminal window remains open after processing for review
- Apps are compiled as standalone bundles with no external dependencies beyond ffmpeg
- AppleScript source included for transparency and customization

---

**Version:** 1.0  
**Last Updated:** May 30, 2026  
**Project:** Movie-Album-Sync
