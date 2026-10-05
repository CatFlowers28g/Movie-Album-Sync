"""Checking GitHub Releases for a newer version, downloading it, and installing it."""

from __future__ import annotations

import json
import os
import platform
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from PySide6.QtCore import QObject, QUrl, Signal
from PySide6.QtNetwork import QNetworkAccessManager, QNetworkReply, QNetworkRequest

from . import __version__

LATEST_RELEASE_API = "https://api.github.com/repos/CatFlowers28g/Movie-Album-Sync/releases/latest"


@dataclass(frozen=True)
class Release:
    version: str
    notes: str
    page_url: str
    download_url: str  # the download for this computer; empty if the release doesn't have one
    download_name: str
    download_size: int


def parse_version(text: str) -> tuple[int, ...]:
    """'v1.2.0' -> (1, 2, 0); anything unreadable counts as oldest."""
    try:
        return tuple(int(part) for part in text.strip().lstrip("vV").split("."))
    except ValueError:
        return (0,)


def is_newer(latest: str, current: str) -> bool:
    return parse_version(latest) > parse_version(current)


def download_suffix() -> str:
    """How this computer's download is named on a release."""
    if os.name == "nt":
        return "-Setup.exe"
    if sys.platform == "darwin":
        return "-Mac-AppleSilicon.dmg" if platform.machine() == "arm64" else "-Mac-Intel.dmg"
    return ""


def parse_release(data: dict, suffix: str) -> Release:
    asset = next((a for a in data.get("assets", []) if suffix and a["name"].endswith(suffix)), None)
    return Release(
        version=data["tag_name"].lstrip("vV"),
        notes=(data.get("body") or "").strip(),
        page_url=data["html_url"],
        download_url=asset["browser_download_url"] if asset else "",
        download_name=asset["name"] if asset else "",
        download_size=asset["size"] if asset else 0,
    )


def can_install(release: Release) -> bool:
    """Whether the app can update itself (it's an installed build and the release has a download for it)."""
    return bool(release.download_url) and getattr(sys, "frozen", False)


def install(download: str):
    """Start installing the downloaded update. The caller should quit the app right after."""
    if os.name == "nt":
        # /SILENT shows only a progress bar; the installer reopens the app when it's done
        subprocess.Popen([download, "/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CLOSEAPPLICATIONS"],
                         creationflags=subprocess.DETACHED_PROCESS)
    elif sys.platform == "darwin":
        subprocess.Popen(["open", download])  # shows the disk image, ready to drag into Applications


def _request(url: str) -> QNetworkRequest:
    request = QNetworkRequest(QUrl(url))
    request.setRawHeader(b"User-Agent", f"MovieAlbumSync/{__version__}".encode())
    request.setRawHeader(b"Accept", b"application/vnd.github+json")
    return request


class UpdateChecker(QObject):
    """Asks GitHub for the latest release."""

    found = Signal(object)  # Release, when it's newer than this version
    up_to_date = Signal()
    failed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._network = QNetworkAccessManager(self)

    def check(self):
        request = _request(LATEST_RELEASE_API)
        request.setTransferTimeout(15_000)
        reply = self._network.get(request)
        reply.finished.connect(lambda: self._finished(reply))

    def _finished(self, reply: QNetworkReply):
        reply.deleteLater()
        if reply.error() != QNetworkReply.NetworkError.NoError:
            self.failed.emit(reply.errorString())
            return
        try:
            release = parse_release(json.loads(bytes(reply.readAll())), download_suffix())
        except (ValueError, KeyError, TypeError) as error:
            self.failed.emit(f"Unexpected answer from GitHub ({error})")
            return
        if is_newer(release.version, __version__):
            self.found.emit(release)
        else:
            self.up_to_date.emit()


class UpdateDownloader(QObject):
    """Downloads a release's installer to a file, reporting progress."""

    progress = Signal(int, int)  # bytes received, total bytes
    done = Signal(str)  # path of the downloaded file
    failed = Signal(str)

    def __init__(self, release: Release, folder: Path, parent=None):
        super().__init__(parent)
        self._release = release
        self._path = folder / release.download_name
        self._network = QNetworkAccessManager(self)
        self._file = None
        self._reply: QNetworkReply | None = None

    def start(self):
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._file = open(self._path, "wb")
        self._reply = self._network.get(_request(self._release.download_url))
        self._reply.readyRead.connect(lambda: self._file.write(bytes(self._reply.readAll())))
        self._reply.downloadProgress.connect(lambda received, total: self.progress.emit(received, total))
        self._reply.finished.connect(self._finished)

    def cancel(self):
        if self._reply:
            self._reply.abort()

    def _finished(self):
        reply = self._reply
        self._file.write(bytes(reply.readAll()))
        self._file.close()
        reply.deleteLater()
        if reply.error() != QNetworkReply.NetworkError.NoError:
            self._path.unlink(missing_ok=True)
            self.failed.emit(reply.errorString())
        elif self._release.download_size and self._path.stat().st_size != self._release.download_size:
            self._path.unlink(missing_ok=True)
            self.failed.emit("The download was incomplete. Please try again.")
        else:
            self.done.emit(str(self._path))
