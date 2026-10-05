"""Finding ffmpeg and running it in the background with progress reporting."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from collections import deque
from pathlib import Path
from typing import Callable

from PySide6.QtCore import QThread, Signal

from .commands import parse_duration

# Keeps a console window from flashing up each time ffmpeg starts on Windows
NO_WINDOW = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
FFMPEG_EXE = "ffmpeg.exe" if os.name == "nt" else "ffmpeg"

# Keys ffmpeg writes with -progress; everything else on the stream is regular log output
PROGRESS_KEYS = {
    "frame", "fps", "bitrate", "total_size", "out_time_us", "out_time_ms", "out_time",
    "dup_frames", "drop_frames", "speed", "progress",
}


def find_ffmpeg() -> str | None:
    """Prefer the ffmpeg bundled with the app, then one next to the app or source, then PATH."""
    roots = []
    if getattr(sys, "frozen", False):
        roots += [Path(sys._MEIPASS), Path(sys.executable).parent]
    roots.append(Path(__file__).resolve().parent.parent)
    for root in roots:
        for candidate in (root / "ffmpeg" / FFMPEG_EXE, root / FFMPEG_EXE):
            if candidate.is_file():
                return str(candidate)
    return shutil.which("ffmpeg")


def media_info(ffmpeg: str, path: str) -> str:
    """ffmpeg's description of a file's format, duration and streams."""
    result = subprocess.run(
        [ffmpeg, "-hide_banner", "-i", path],
        stdin=subprocess.DEVNULL, capture_output=True, text=True,
        encoding="utf-8", errors="replace", creationflags=NO_WINDOW,
    )
    lines = [line for line in result.stderr.splitlines() if "At least one output file must be specified" not in line]
    return "\n".join(lines).strip()


def probe_duration(ffmpeg: str, path: str) -> float | None:
    return parse_duration(media_info(ffmpeg, path))


class FFmpegJob(QThread):
    """Runs one ffmpeg command off the UI thread and reports progress as it goes."""

    progress = Signal(float, object)  # fraction done 0-1 (-1 if unknown), seconds remaining or None
    log_line = Signal(str)
    done = Signal(bool, str)  # success, message

    def __init__(self, ffmpeg: str, args: list[str], expected_seconds: Callable[[], float | None] | None = None,
                 output: str | None = None, parent=None):
        super().__init__(parent)
        self._ffmpeg = ffmpeg
        self._args = args
        self._expected_seconds = expected_seconds
        self._output = output
        self._process: subprocess.Popen | None = None
        self._cancelled = False
        self._recent_log = deque(maxlen=8)

    def cancel(self):
        """Ask ffmpeg to stop (it quits cleanly on 'q'), killing it if that fails."""
        self._cancelled = True
        process = self._process
        if process is None or process.poll() is not None:
            return
        try:
            process.stdin.write("q\n")
            process.stdin.flush()
        except (OSError, ValueError):
            process.kill()

    def run(self):
        try:
            total = self._expected_seconds() if self._expected_seconds else None
        except Exception:
            total = None

        self.log_line.emit("ffmpeg " + subprocess.list2cmdline(self._args))
        try:
            self._process = subprocess.Popen(
                [self._ffmpeg, "-hide_banner", "-nostats", "-progress", "pipe:1", "-y", *self._args],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace", bufsize=1, creationflags=NO_WINDOW,
            )
        except OSError as error:
            self.done.emit(False, f"Couldn't start ffmpeg: {error}")
            return
        if self._cancelled:  # Cancel was pressed while durations were being measured
            self.cancel()

        position, speed = 0.0, None
        for line in self._process.stdout:
            line = line.rstrip()
            key, separator, value = line.partition("=")
            if separator and (key in PROGRESS_KEYS or key.startswith("stream_")):
                if key == "out_time_us":
                    try:
                        position = max(0.0, int(value) / 1_000_000)
                    except ValueError:
                        pass
                elif key == "speed":
                    try:
                        speed = float(value.rstrip("x"))
                    except ValueError:
                        speed = None
                elif key == "progress":
                    self._report(position, speed, total)
                continue
            if line:
                self._recent_log.append(line)
                self.log_line.emit(line)

        exit_code = self._process.wait()
        if self._cancelled or exit_code != 0:
            self._remove_partial_output()
        if self._cancelled:
            self.done.emit(False, "Cancelled.")
        elif exit_code != 0:
            details = "\n".join(list(self._recent_log)[-3:])
            self.done.emit(False, f"ffmpeg stopped with an error:\n{details}")
        else:
            self.done.emit(True, "Done!")

    def _report(self, position: float, speed: float | None, total: float | None):
        if not total:
            self.progress.emit(-1.0, None)
            return
        remaining = (total - position) / speed if speed else None
        self.progress.emit(min(position / total, 1.0), max(remaining, 0.0) if remaining is not None else None)

    def _remove_partial_output(self):
        if self._output:
            try:
                Path(self._output).unlink(missing_ok=True)
            except OSError:
                pass
