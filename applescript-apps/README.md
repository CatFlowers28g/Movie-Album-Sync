# FFmpeg AppleScript Apps

Five standalone macOS applications for streamlined ffmpeg workflows. Each app provides a user-friendly interface with dialog prompts instead of requiring terminal knowledge.

## Apps Included

### 1. **Movie Sync Audio** 
Syncs an audio track to a video file with customizable delay.

**Features:**
- Select video file (MKV or MP4)
- Select audio file (FLAC or MP3)
- Set audio delay in milliseconds (default: 36000ms = 36 seconds)
- Specify output filename and location
- Real-time progress in Terminal

**Output Format:** Matroska (MKV) with copied video + FLAC audio

**Use Case:** Sync Dark Side of the Moon to Wizard of Oz, or any other album to film combination.

---

### 2. **FFmpeg Info Logger**
Generates detailed ffmpeg information and diagnostics for any media file.

**Features:**
- Select any media file (video, audio, etc.)
- Auto-generates log filename based on input
- Produces complete ffmpeg analysis output
- Shows stream info, codecs, duration, bitrates, etc.

**Output Format:** Text file with full ffmpeg verbose output

**Use Case:** Analyze media files before processing, check codec compatibility, inspect stream information.

---

### 3. **FLAC Combiner**
Merges multiple FLAC audio files into a single file using ffmpeg's concat demuxer.

**Features:**
- Select multiple FLAC files at once
- Auto-creates concat list file
- Choose output filename and location
- Lossless audio merging (no re-encoding)

**Output Format:** Single FLAC file

**Use Case:** Combine individual album tracks or segments into one continuous file.

---

### 4. **Test Clip Extractor**
Extracts a short segment from the beginning of your video with audio sync already applied.

**Features:**
- Select video and audio files
- Set clip duration in minutes (default: 3 minutes)
- Set audio delay matching your main sync settings
- Specify output filename and location
- Fast extraction with audio sync validated

**Output Format:** Matroska (MKV) with trimmed video + synced audio

**Use Case:** Quick verification that audio/video sync timing is correct before running full encoding. Extract first 3 minutes, watch it, and if sync is perfect, run the main "Movie Sync Audio" app for the full video.

---

### 5. **Video/Audio Re-Encoder** ⭐ NEW
Re-encodes video and/or audio files with customizable resolution, codec, and quality settings.

**Features:**
- Process video only, audio only, or both simultaneously
- **Video Codec Presets:** H.264 (MP4), HEVC/H.265 (MP4), VP9 (WebM), ProRes (MOV)
- **Resolution Presets:** 4K (2160p), 1080p (Full HD), 720p (HD), 480p (SD), or custom
- **Video Quality:** Low (1500kbps), Medium (3000kbps), High (6000kbps), Very High (12000kbps), or custom
- **Audio Codec Presets:** AAC (MP4), FLAC (Lossless), MP3, Opus
- **Audio Quality:** Low (128kbps), Medium (192kbps), High (320kbps), Lossless, or custom
- Automatic timestamp-based output naming
- Real-time progress display in Terminal

**Output Formats:** MP4, WebM, MOV, FLAC, MP3, M4A, or Opus (depending on selections)

**Use Case:** Convert videos between formats, reduce file size with lower bitrates, upscale/downscale resolution, convert between audio codecs, create multi-format versions for different platforms.

---

## Installation & Usage

### Quick Start

1. **The apps are already compiled and located at:**
   ```
   ~/Applications/Movie Sync Audio.app
   ~/Applications/FFmpeg Info Logger.app
   ~/Applications/FLAC Combiner.app
   ~/Applications/Test Clip Extractor.app
   ~/Applications/Video Audio Re-Encoder.app
   ```

2. **To run an app:**
   - Open Finder → Applications (or ~/Applications)
   - Double-click the desired .app
   - Follow the dialog prompts to select files and parameters
   - Terminal window opens automatically to show processing progress

3. **If you need to recompile the apps:**
   ```bash
   cd /path/to/applescript-apps
   bash compile-apps.sh
   ```
   This will recompile all scripts from their source files and place updated .app files in ~/Applications

---

## Recommended Workflow

### For syncing audio to video (like album to film):

1. **First, create an FFmpeg Log** to inspect your files
   - Run: **FFmpeg Info Logger**
   - Select your video and audio files
   - Review the generated .txt logs to confirm codecs and streams

2. **Test with a short clip** to verify sync timing
   - Run: **Test Clip Extractor**
   - Extract first 3 minutes with your desired audio delay
   - Watch the test clip to confirm audio/video sync is correct

3. **Extract and combine audio if needed**
   - Run: **FLAC Combiner** (if you have separate FLAC tracks)
   - Merge individual tracks into one continuous audio file

4. **Create the final synced video**
   - Run: **Movie Sync Audio**
   - Use the same audio delay you validated in step 2
   - Process full-length video and audio

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
- `01-Movie-Sync-Audio.applescript`
- `02-FFmpeg-Info-Logger.applescript`
- `03-FLAC-Combiner.applescript`
- `04-Test-Clip-Extractor.applescript`
- `05-Video-Audio-Reencoder.applescript`

You can edit these files and recompile using `compile-apps.sh` if you need to customize behavior or commands.

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
