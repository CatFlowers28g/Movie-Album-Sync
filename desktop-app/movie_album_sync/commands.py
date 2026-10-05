"""ffmpeg argument builders for each tool.

Pure functions with no Qt or subprocess code, so the ffmpeg logic is easy to test.
The commands match the original AppleScript toolkit in applescript-apps/.
"""

from __future__ import annotations

import re
from pathlib import Path

VIDEO_EXTENSIONS = ("mp4", "mkv", "mov", "m4v", "avi", "webm")
AUDIO_EXTENSIONS = ("flac", "mp3", "wav", "m4a", "aac", "ogg", "opus", "aiff")

CONTAINERS = {"MP4": "mp4", "MKV": "mkv", "MOV": "mov"}

BEST_QUALITY = "Best quality (MKV, lossless audio)"
PLAYS_EVERYWHERE = "Plays everywhere (MP4, AAC audio)"
SYNC_FORMATS = {BEST_QUALITY: "mkv", PLAYS_EVERYWHERE: "mp4"}
FLAC_AUDIO = ["-c:a", "flac"]
AAC_AUDIO = ["-c:a", "aac", "-b:a", "320k"]

KEEP_VIDEO = "Keep original (fastest, no quality loss)"
H264_VIDEO = "H.264 (plays everywhere)"
H265_VIDEO = "H.265 / HEVC (smaller file)"
VIDEO_CODECS = {
    KEEP_VIDEO: ["-c:v", "copy"],
    H264_VIDEO: ["-c:v", "libx264", "-preset", "slow", "-crf", "18"],
    H265_VIDEO: ["-c:v", "libx265", "-preset", "slow", "-crf", "22"],
}

CUSTOM_RESOLUTION = "Custom height..."
RESOLUTIONS = {
    "Keep original": 0,
    "1080p (Full HD)": 1080,
    "720p (HD)": 720,
    "480p (SD)": 480,
    CUSTOM_RESOLUTION: 0,
}

AUDIO_CODECS = {
    "Keep original": ["-c:a", "copy"],
    "AAC 320k (plays everywhere)": ["-c:a", "aac", "-b:a", "320k"],
    "ALAC (lossless, Apple)": ["-c:a", "alac"],
    "FLAC (lossless)": ["-c:a", "flac"],
}

_DURATION = re.compile(r"Duration:\s*(\d+):(\d{2}):(\d{2}(?:\.\d+)?)")


def format_seconds(ms: int) -> str:
    """Milliseconds as a seconds string for ffmpeg, e.g. 5250 -> '5.25'."""
    return f"{ms / 1000:.3f}".rstrip("0").rstrip(".")


def sync_filter_args(offset_ms: int, audio_codec: list[str] = FLAC_AUDIO) -> list[str]:
    """Filter, map and codec arguments that offset input 1's audio against input 0's video.

    Positive offsets delay the audio. Negative offsets add black frames before the
    video so the audio starts first, which means the video has to be re-encoded.
    """
    if offset_ms >= 0:
        return [
            "-filter_complex", f"[1:a]adelay={offset_ms}|{offset_ms},apad[aud]",
            "-map", "0:v", "-map", "[aud]",
            "-c:v", "copy", *audio_codec,
        ]
    lead = format_seconds(-offset_ms)
    return [
        "-filter_complex", f"[0:v]tpad=start_duration={lead}:start_mode=add:color=black[v];[1:a]apad[aud]",
        "-map", "[v]", "-map", "[aud]",
        "-c:v", "libx264", "-preset", "slow", "-crf", "18", *audio_codec,
    ]


def sync_args(video: str, album: str, offset_ms: int, output: str, preview_seconds: int | None = None,
              mp4: bool = False, hevc_video: bool = False) -> list[str]:
    """Sync the album to the movie; with preview_seconds, only render that much from the start.

    mp4 switches to the plays-everywhere format (AAC audio). hevc_video says the movie's
    video is HEVC, which needs an 'hvc1' tag in MP4 for Apple devices to play it.
    """
    args = ["-i", video, "-stream_loop", "-1", "-i", album]
    if preview_seconds:
        args += ["-t", str(preview_seconds)]
    args += sync_filter_args(offset_ms, AAC_AUDIO if mp4 else FLAC_AUDIO)
    if mp4:
        if hevc_video and offset_ms >= 0:  # only when the video is copied; negative offsets re-encode to H.264
            args += ["-tag:v", "hvc1"]
        args += ["-movflags", "+faststart"]
    return args + ["-shortest", output]


def concat_list(paths: list[str]) -> str:
    """Contents of an ffmpeg concat list file for the given tracks, in order."""
    lines = []
    for path in paths:
        escaped = str(path).replace("\\", "/").replace("'", "'\\''")
        lines.append(f"file '{escaped}'")
    return "\n".join(lines) + "\n"


def combine_args(list_file: str, output: str) -> list[str]:
    return ["-f", "concat", "-safe", "0", "-i", list_file, "-c:a", "flac", output]


def transcode_args(source: str, output: str, video_codec: str, height: int, audio_codec: str) -> list[str]:
    """Convert to another container/codec; a height of 0 keeps the original resolution."""
    if video_codec == KEEP_VIDEO and height:
        video_codec = H264_VIDEO  # resizing needs a re-encode
    args = ["-i", source]
    if height:
        args += ["-vf", f"scale=-2:{height}"]
    return args + VIDEO_CODECS[video_codec] + AUDIO_CODECS[audio_codec] + ["-movflags", "+faststart", output]


def parse_duration(ffmpeg_output: str) -> float | None:
    """The first 'Duration: HH:MM:SS.ss' in ffmpeg's output, in seconds."""
    match = _DURATION.search(ffmpeg_output)
    if not match:
        return None
    hours, minutes, seconds = match.groups()
    return int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def natural_sort_key(path: str) -> list:
    """Sort key that orders 'Track 2' before 'Track 10'."""
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", Path(path).name.lower())]
