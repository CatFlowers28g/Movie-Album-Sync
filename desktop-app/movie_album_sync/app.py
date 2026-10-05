"""Main window for Movie Album Sync."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Callable

from PySide6.QtCore import QSettings, Qt, QUrl, Signal
from PySide6.QtGui import QColor, QDesktopServices, QFontDatabase, QIcon, QPainter, QPalette
from PySide6.QtWidgets import (
    QAbstractItemView, QApplication, QComboBox, QDoubleSpinBox, QFileDialog, QFormLayout, QFrame,
    QHBoxLayout, QLabel, QLineEdit, QListWidget, QListWidgetItem, QMainWindow, QMessageBox,
    QPlainTextEdit, QProgressBar, QPushButton, QSpinBox, QTabWidget, QVBoxLayout, QWidget,
)

from . import __version__, commands
from .ffmpeg import FFmpegJob, find_ffmpeg, media_info, probe_duration

APP_NAME = "Movie Album Sync"
ACCENT = "#7C3AED"
ACCENT_HOVER = "#6D28D9"
TEMP_DIR = Path(tempfile.gettempdir()) / "MovieAlbumSync"

PRIMARY_BUTTON_STYLE = f"""
QPushButton {{ background: {ACCENT}; color: white; border: none; border-radius: 6px; padding: 8px 22px; font-weight: 600; }}
QPushButton:hover {{ background: {ACCENT_HOVER}; }}
QPushButton:disabled {{ background: #B9A6E8; }}
"""
PROGRESS_STYLE = f"""
QProgressBar {{ border: none; border-radius: 6px; background: rgba(128, 128, 128, 60); min-height: 12px; max-height: 12px; }}
QProgressBar::chunk {{ background: {ACCENT}; border-radius: 5px; }}
"""


def _file_filter(label: str, extensions: tuple[str, ...]) -> str:
    return f"{label} ({' '.join('*.' + e for e in extensions)});;All files (*)"


VIDEO_FILTER = _file_filter("Video files", commands.VIDEO_EXTENSIONS)
AUDIO_FILTER = _file_filter("Audio files", commands.AUDIO_EXTENSIONS)
MEDIA_FILTER = _file_filter("Media files", commands.VIDEO_EXTENSIONS + commands.AUDIO_EXTENSIONS)


def resource_path(relative: str) -> Path:
    """A file shipped with the app, whether running from source or from a PyInstaller build."""
    return Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent.parent)) / relative


def open_file(path: str):
    QDesktopServices.openUrl(QUrl.fromLocalFile(path))


def show_in_folder(path: str):
    if os.name == "nt":
        subprocess.Popen(f'explorer /select,"{os.path.normpath(path)}"')
    elif sys.platform == "darwin":
        subprocess.Popen(["open", "-R", path])
    else:
        open_file(str(Path(path).parent))


def describe_time(seconds: float) -> str:
    if seconds < 60:
        return "less than a minute"
    minutes = round(seconds / 60)
    if minutes < 60:
        return f"{minutes} min"
    return f"{minutes // 60} h {minutes % 60} min"


def same_path(a: str, b: str) -> bool:
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def hint_label(text: str = "") -> QLabel:
    label = QLabel(text)
    label.setWordWrap(True)
    label.setStyleSheet("color: #888;")
    return label


def primary_button(text: str) -> QPushButton:
    button = QPushButton(text)
    button.setStyleSheet(PRIMARY_BUTTON_STYLE)
    button.setCursor(Qt.CursorShape.PointingHandCursor)
    return button


def clean_temp_files():
    """Remove previews and track lists left over from earlier runs."""
    for pattern in ("preview-*.mkv", "tracks-*.txt"):
        for path in TEMP_DIR.glob(pattern):
            try:
                path.unlink()
            except OSError:
                pass  # still open in a video player


class PathField(QWidget):
    """A file path box with a Browse button. Files can also be dragged onto it."""

    changed = Signal(str)

    def __init__(self, settings: QSettings, placeholder: str, dialog_title: str, file_filter: str, save: bool = False):
        super().__init__()
        self._settings = settings
        self._dialog_title = dialog_title
        self._save = save
        self._last = ""
        self.file_filter = file_filter
        self.chosen_by_user = False  # once set, suggestions stop replacing the path
        self.overwrite_confirmed = False  # the Save dialog already asked about replacing the file

        self.edit = QLineEdit()
        self.edit.setPlaceholderText(placeholder)
        self.edit.setAcceptDrops(False)  # let drops reach this widget instead of inserting text
        self.edit.editingFinished.connect(self._typed)
        button = QPushButton("Change..." if save else "Browse...")
        button.clicked.connect(self.browse)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.edit, 1)
        layout.addWidget(button)
        self.setAcceptDrops(not save)

    def path(self) -> str:
        return self.edit.text().strip().strip('"')

    def set_path(self, path: str, chosen_by_user: bool = True, overwrite_confirmed: bool = False):
        path = os.path.normpath(path) if path else ""
        self.edit.setText(path)
        self._last = path
        self.chosen_by_user = chosen_by_user
        self.overwrite_confirmed = overwrite_confirmed
        if path and chosen_by_user:
            self._settings.setValue("last_folder", str(Path(path).parent))
        self.changed.emit(path)

    def suggest(self, path: str):
        """Fill in a default, unless the user has already picked something."""
        if not self.chosen_by_user:
            self.set_path(path, chosen_by_user=False)

    def browse(self):
        start = self.path() or self._settings.value("last_folder", str(Path.home()))
        if self._save:
            path, _ = QFileDialog.getSaveFileName(self, self._dialog_title, start, self.file_filter)
        else:
            path, _ = QFileDialog.getOpenFileName(self, self._dialog_title, start, self.file_filter)
        if path:
            self.set_path(path, overwrite_confirmed=self._save)

    def _typed(self):
        if self.path() != self._last:
            self.set_path(self.path())

    def dragEnterEvent(self, event):
        if self._dropped_file(event):
            event.acceptProposedAction()

    def dropEvent(self, event):
        path = self._dropped_file(event)
        if path:
            self.set_path(path)
            event.acceptProposedAction()

    @staticmethod
    def _dropped_file(event) -> str:
        urls = event.mimeData().urls()
        return urls[0].toLocalFile() if urls and urls[0].isLocalFile() else ""


class Page(QWidget):
    """One tab: an intro line, a form of fields, and action buttons."""

    def __init__(self, main: MainWindow, intro: str):
        super().__init__()
        self.main = main
        self.page_layout = QVBoxLayout(self)
        self.page_layout.setContentsMargins(16, 14, 16, 10)
        intro_label = QLabel(intro)
        intro_label.setWordWrap(True)
        self.page_layout.addWidget(intro_label)
        self.page_layout.addSpacing(6)
        self.form = QFormLayout()
        self.form.setVerticalSpacing(10)
        self.page_layout.addLayout(self.form)

    def path_field(self, placeholder: str, title: str, file_filter: str, save: bool = False) -> PathField:
        return PathField(self.main.settings, placeholder, title, file_filter, save)

    def add_buttons(self, *widgets: QWidget):
        row = QHBoxLayout()
        row.addStretch()
        for widget in widgets:
            row.addWidget(widget)
        self.page_layout.addLayout(row)

    def save_settings(self):
        """Remember this tab's choices for next time (pages override as needed)."""

    def warn(self, message: str):
        QMessageBox.warning(self, APP_NAME, message)

    def check_inputs(self, *files: tuple[str, str]) -> bool:
        for path, name in files:
            if not path:
                self.warn(f"Please choose the {name} first.")
                return False
            if not os.path.isfile(path):
                self.warn(f"Can't find the {name}:\n{path}")
                return False
        return True

    def check_output(self, field: PathField, inputs: list[str]) -> str | None:
        """The output path if it's usable, after confirming any overwrite; otherwise None."""
        output = field.path()
        if not output:
            self.warn("Please choose where to save the result.")
            return None
        if any(same_path(output, path) for path in inputs):
            self.warn("The result can't replace one of the files you're using. Please choose a different name.")
            return None
        folder = os.path.dirname(output)
        if not os.path.isabs(output) or not os.path.isdir(folder):
            self.warn(f"This folder doesn't exist:\n{folder or output}\n\nUse Change... to pick where to save.")
            return None
        if os.path.exists(output) and not field.overwrite_confirmed:
            answer = QMessageBox.question(self, APP_NAME, f"{os.path.basename(output)} already exists.\nDo you want to replace it?")
            if answer != QMessageBox.StandardButton.Yes:
                return None
        return output


class SyncPage(Page):
    def __init__(self, main: MainWindow):
        super().__init__(main, "Put an album's audio onto a movie, starting exactly when you want it to.")
        settings = main.settings

        self.movie = self.path_field("Choose or drag in the movie...", "Choose the movie", VIDEO_FILTER)
        self.album = self.path_field("Choose or drag in the album...", "Choose the album", AUDIO_FILTER)
        self.output = self.path_field("Where to save the synced movie", "Save the synced movie as", "", save=True)
        self.movie.changed.connect(self._suggest_output)
        self.format = QComboBox()
        self.format.addItems(list(commands.SYNC_FORMATS))
        self.format.setCurrentText(settings.value("sync/format", commands.BEST_QUALITY))
        self.format.currentTextChanged.connect(self._format_changed)

        self.offset = QDoubleSpinBox()
        self.offset.setRange(0, 86400)
        self.offset.setDecimals(3)
        self.offset.setSingleStep(0.5)
        self.offset.setSuffix(" seconds")
        self.offset.setValue(settings.value("sync/offset_seconds", 36.0, type=float))
        self.direction = QComboBox()
        self.direction.addItems(["after", "before"])
        self.direction.setCurrentIndex(settings.value("sync/direction", 0, type=int))
        self.direction.currentIndexChanged.connect(self._update_hint)
        timing = QHBoxLayout()
        timing.addWidget(QLabel("The album starts"))
        timing.addWidget(self.offset)
        timing.addWidget(self.direction)
        timing.addWidget(QLabel("the movie"))
        timing.addStretch()
        self.timing_hint = hint_label()

        self.form.addRow("Movie:", self.movie)
        self.form.addRow("Album:", self.album)
        self.form.addRow("", hint_label("Album split into separate tracks? Join them on the Combine Tracks tab first."))
        self.form.addRow("Timing:", timing)
        self.form.addRow("", self.timing_hint)
        self.form.addRow("Format:", self.format)
        self.form.addRow("", hint_label("Best quality keeps the album lossless, but some TVs and phones can't play it. "
                                        "Plays everywhere works on almost any device."))
        self.form.addRow("Save as:", self.output)
        self.page_layout.addStretch()

        self.preview_minutes = QSpinBox()
        self.preview_minutes.setRange(1, 30)
        self.preview_minutes.setSuffix(" min")
        self.preview_minutes.setValue(settings.value("sync/preview_minutes", 3, type=int))
        preview = QPushButton("Preview")
        preview.setToolTip("Make a short clip from the start of the movie and play it, to check the timing.")
        preview.clicked.connect(lambda: self.run(preview=True))
        sync = primary_button("Sync Movie")
        sync.clicked.connect(lambda: self.run(preview=False))
        self.add_buttons(QLabel("Preview the first"), self.preview_minutes, preview, sync)
        self._update_hint()
        self._format_changed()

    def save_settings(self):
        settings = self.main.settings
        settings.setValue("sync/offset_seconds", self.offset.value())
        settings.setValue("sync/direction", self.direction.currentIndex())
        settings.setValue("sync/preview_minutes", self.preview_minutes.value())
        settings.setValue("sync/format", self.format.currentText())

    def extension(self) -> str:
        return commands.SYNC_FORMATS[self.format.currentText()]

    def offset_ms(self) -> int:
        ms = round(self.offset.value() * 1000)
        return -ms if self.direction.currentIndex() == 1 else ms

    def run(self, preview: bool):
        movie, album = self.movie.path(), self.album.path()
        if not self.check_inputs((movie, "movie"), (album, "album")):
            return
        if preview:
            TEMP_DIR.mkdir(parents=True, exist_ok=True)
            output = str(TEMP_DIR / f"preview-{int(time.time())}.{self.extension()}")
        else:
            output = self.check_output(self.output, [movie, album])
            if not output:
                return
        self.save_settings()

        offset_ms = self.offset_ms()
        preview_seconds = self.preview_minutes.value() * 60 if preview else None
        lead = max(0, -offset_ms) / 1000
        ffmpeg = self.main.ffmpeg
        mp4 = self.extension() == "mp4"
        hevc_video = mp4 and "Video: hevc" in media_info(ffmpeg, movie)

        def expected_seconds():
            duration = probe_duration(ffmpeg, movie)
            total = duration + lead if duration else None
            return min(total or preview_seconds, preview_seconds) if preview_seconds else total

        self.main.start_job(
            "Making the preview" if preview else "Syncing",
            commands.sync_args(movie, album, offset_ms, output, preview_seconds, mp4, hevc_video),
            expected_seconds, output,
            on_success=self._preview_ready if preview else None,
        )

    def _preview_ready(self, output: str) -> str:
        open_file(output)
        return "The preview is ready and should open in your video player. Adjust the timing and preview again if needed."

    def _suggest_output(self, movie: str):
        if movie:
            self.output.suggest(str(Path(movie).with_name(f"{Path(movie).stem} (synced).{self.extension()}")))

    def _format_changed(self):
        extension = self.extension()
        self.output.file_filter = f"{extension.upper()} video (*.{extension});;All files (*)"
        if self.output.path():
            self.output.set_path(str(Path(self.output.path()).with_suffix("." + extension)),
                                 chosen_by_user=self.output.chosen_by_user)

    def _update_hint(self):
        if self.direction.currentIndex() == 0:
            self.timing_hint.setText("The album replaces the movie's soundtrack. It's silent until the album starts.")
        else:
            self.timing_hint.setText("A black screen is added at the start so the album can begin first. "
                                     "The video has to be re-encoded for this, so it takes much longer.")


class TrackList(QListWidget):
    """Tracks that can be reordered by dragging, and that accepts files dropped from Explorer/Finder."""

    files_dropped = Signal(list)

    def __init__(self):
        super().__init__()
        self.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.setAcceptDrops(True)

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            super().dragEnterEvent(event)

    def dragMoveEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            super().dragMoveEvent(event)

    def dropEvent(self, event):
        if event.mimeData().hasUrls():
            self.files_dropped.emit([url.toLocalFile() for url in event.mimeData().urls() if url.isLocalFile()])
            event.acceptProposedAction()
        else:
            super().dropEvent(event)

    def paintEvent(self, event):
        super().paintEvent(event)
        if self.count() == 0:
            painter = QPainter(self.viewport())
            painter.setPen(QColor("#888"))
            painter.drawText(self.viewport().rect(), Qt.AlignmentFlag.AlignCenter,
                             "Drag the album's tracks here,\nor click Add Tracks...")


class CombinePage(Page):
    def __init__(self, main: MainWindow, sync_page: SyncPage):
        super().__init__(main, "Join an album's separate tracks into one file, in the order shown. "
                               "Drag tracks up or down to change the order.")
        self.sync_page = sync_page

        self.tracks = TrackList()
        self.tracks.files_dropped.connect(self.add_tracks)
        side = QVBoxLayout()
        for text, action in (("Add Tracks...", self.browse), ("Remove", self.remove),
                             ("Move Up", lambda: self.move(-1)), ("Move Down", lambda: self.move(1)),
                             ("Sort by Name", self.sort_by_name), ("Clear", self.tracks.clear)):
            button = QPushButton(text)
            button.clicked.connect(action)
            side.addWidget(button)
        side.addStretch()
        track_row = QHBoxLayout()
        track_row.addWidget(self.tracks, 1)
        track_row.addLayout(side)

        self.output = self.path_field("Where to save the combined album", "Save the combined album as",
                                      "FLAC audio (*.flac);;All files (*)", save=True)
        self.form.addRow("Tracks:", track_row)
        self.form.addRow("Save as:", self.output)

        combine = primary_button("Combine Tracks")
        combine.clicked.connect(self.run)
        self.add_buttons(combine)

    def paths(self) -> list[str]:
        return [self.tracks.item(row).data(Qt.ItemDataRole.UserRole) for row in range(self.tracks.count())]

    def browse(self):
        start = self.main.settings.value("last_folder", str(Path.home()))
        paths, _ = QFileDialog.getOpenFileNames(self, "Choose the album's tracks", start, AUDIO_FILTER)
        self.add_tracks(paths)

    def add_tracks(self, paths: list[str]):
        paths = sorted((os.path.normpath(p) for p in paths if os.path.isfile(p)), key=commands.natural_sort_key)
        for path in paths:
            item = QListWidgetItem(os.path.basename(path))
            item.setData(Qt.ItemDataRole.UserRole, path)
            item.setToolTip(path)
            self.tracks.addItem(item)
        if paths:
            self.main.settings.setValue("last_folder", os.path.dirname(paths[0]))
            folder = Path(self.paths()[0]).parent
            self.output.suggest(str(folder / f"{folder.name or 'Album'} (combined).flac"))

    def remove(self):
        for item in self.tracks.selectedItems():
            self.tracks.takeItem(self.tracks.row(item))

    def move(self, step: int):
        rows = sorted(self.tracks.row(item) for item in self.tracks.selectedItems())
        if not rows or (step < 0 and rows[0] == 0) or (step > 0 and rows[-1] == self.tracks.count() - 1):
            return
        for row in (rows if step < 0 else reversed(rows)):
            item = self.tracks.takeItem(row)
            self.tracks.insertItem(row + step, item)
            item.setSelected(True)

    def sort_by_name(self):
        paths = self.paths()
        self.tracks.clear()
        self.add_tracks(paths)

    def run(self):
        paths = self.paths()
        if len(paths) < 2:
            self.warn("Add at least two tracks to combine.")
            return
        missing = next((path for path in paths if not os.path.isfile(path)), None)
        if missing:
            self.warn(f"Can't find this track anymore:\n{missing}")
            return
        output = self.check_output(self.output, paths)
        if not output:
            return

        TEMP_DIR.mkdir(parents=True, exist_ok=True)
        list_file = TEMP_DIR / f"tracks-{int(time.time())}.txt"
        list_file.write_text(commands.concat_list(paths), encoding="utf-8", newline="\n")
        ffmpeg = self.main.ffmpeg

        def expected_seconds():
            durations = [probe_duration(ffmpeg, path) for path in paths]
            return sum(durations) if all(durations) else None

        self.main.start_job("Combining tracks", commands.combine_args(str(list_file), output),
                            expected_seconds, output, on_success=self._combined)

    def _combined(self, output: str) -> str:
        self.sync_page.album.set_path(output)
        return f"Done! Saved {os.path.basename(output)}. It's been added to the Sync Album tab, ready to use."


class ConvertPage(Page):
    def __init__(self, main: MainWindow):
        super().__init__(main, "Convert a video to a different format, codec, or size.")
        settings = main.settings

        self.source = self.path_field("Choose or drag in a video...", "Choose the video to convert", VIDEO_FILTER)
        self.source.changed.connect(self._suggest_output)
        self.container = self._combo(commands.CONTAINERS, settings.value("convert/container", "MP4"))
        self.video = self._combo(commands.VIDEO_CODECS, settings.value("convert/video", commands.H265_VIDEO))
        self.resolution = self._combo(commands.RESOLUTIONS, settings.value("convert/resolution", "Keep original"))
        self.height = QSpinBox()
        self.height.setRange(144, 4320)
        self.height.setSuffix(" pixels tall")
        self.height.setValue(settings.value("convert/height", 1080, type=int))
        resolution_row = QHBoxLayout()
        resolution_row.addWidget(self.resolution, 1)
        resolution_row.addWidget(self.height)
        self.audio = self._combo(commands.AUDIO_CODECS, settings.value("convert/audio", "Keep original"))
        self.resize_note = hint_label("Resizing needs the video to be re-encoded, so it will be converted to H.264.")
        self.output = self.path_field("Where to save the converted video", "Save the converted video as", "", save=True)

        self.form.addRow("Video:", self.source)
        self.form.addRow("Format:", self.container)
        self.form.addRow("Video codec:", self.video)
        self.form.addRow("Size:", resolution_row)
        self.form.addRow("", self.resize_note)
        self.form.addRow("Audio:", self.audio)
        self.form.addRow("Save as:", self.output)
        self.page_layout.addStretch()

        convert = primary_button("Convert")
        convert.clicked.connect(self.run)
        self.add_buttons(convert)

        self.container.currentTextChanged.connect(self._container_changed)
        self.video.currentTextChanged.connect(self._update)
        self.resolution.currentTextChanged.connect(self._update)
        self.height.valueChanged.connect(self._update)
        self._container_changed()
        self._update()

    @staticmethod
    def _combo(items, current: str) -> QComboBox:
        combo = QComboBox()
        combo.addItems(list(items))
        if current in items:
            combo.setCurrentText(current)
        return combo

    def save_settings(self):
        settings = self.main.settings
        settings.setValue("convert/container", self.container.currentText())
        settings.setValue("convert/video", self.video.currentText())
        settings.setValue("convert/resolution", self.resolution.currentText())
        settings.setValue("convert/height", self.height.value())
        settings.setValue("convert/audio", self.audio.currentText())

    def target_height(self) -> int:
        if self.resolution.currentText() == commands.CUSTOM_RESOLUTION:
            return self.height.value()
        return commands.RESOLUTIONS[self.resolution.currentText()]

    def extension(self) -> str:
        return commands.CONTAINERS[self.container.currentText()]

    def run(self):
        source = self.source.path()
        if not self.check_inputs((source, "video")):
            return
        output = self.check_output(self.output, [source])
        if not output:
            return
        self.save_settings()
        ffmpeg = self.main.ffmpeg
        args = commands.transcode_args(source, output, self.video.currentText(), self.target_height(),
                                       self.audio.currentText())
        self.main.start_job("Converting", args, lambda: probe_duration(ffmpeg, source), output)

    def _suggest_output(self, source: str):
        if source:
            self.output.suggest(str(Path(source).with_name(f"{Path(source).stem} (converted).{self.extension()}")))

    def _container_changed(self):
        name, extension = self.container.currentText(), self.extension()
        self.output.file_filter = f"{name} video (*.{extension});;All files (*)"
        if self.output.path():
            self.output.set_path(str(Path(self.output.path()).with_suffix("." + extension)),
                                 chosen_by_user=self.output.chosen_by_user)

    def _update(self):
        self.height.setVisible(self.resolution.currentText() == commands.CUSTOM_RESOLUTION)
        self.resize_note.setVisible(self.video.currentText() == commands.KEEP_VIDEO and self.target_height() > 0)


class InfoPage(Page):
    def __init__(self, main: MainWindow):
        super().__init__(main, "See what's inside a video or audio file: its length, format, and streams.")
        self.file = self.path_field("Choose or drag in a file...", "Choose a file to inspect", MEDIA_FILTER)
        self.file.changed.connect(self.inspect)
        self.details = QPlainTextEdit()
        self.details.setReadOnly(True)
        self.details.setFont(QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont))
        self.details.setPlaceholderText("Choose a file to see its details here.")
        self.form.addRow("File:", self.file)
        self.page_layout.addWidget(self.details, 1)

        save = QPushButton("Save as Text File...")
        save.clicked.connect(self.save)
        self.add_buttons(save)

    def inspect(self, path: str):
        if not path or not os.path.isfile(path):
            return
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            text = media_info(self.main.ffmpeg, path)
        finally:
            QApplication.restoreOverrideCursor()
        self.details.setPlainText(text or "ffmpeg couldn't read this file.")

    def save(self):
        source, text = self.file.path(), self.details.toPlainText()
        if not text:
            self.warn("Choose a file first.")
            return
        default = Path(source).with_name(f"{Path(source).stem}_ffmpeg_log.txt")
        path, _ = QFileDialog.getSaveFileName(self, "Save details as", str(default), "Text files (*.txt)")
        if path:
            Path(path).write_text(text + "\n", encoding="utf-8")


class MainWindow(QMainWindow):
    def __init__(self, ffmpeg: str):
        super().__init__()
        self.ffmpeg = ffmpeg
        self.settings = QSettings("MovieAlbumSync", APP_NAME)
        self.job: FFmpegJob | None = None
        self._job_title = ""
        self._job_output = ""
        self._on_success: Callable[[str], str | None] | None = None

        self.setWindowTitle(APP_NAME)
        self.resize(800, 640)
        self.setMinimumSize(660, 540)

        self.sync_page = SyncPage(self)
        self.pages = [self.sync_page, CombinePage(self, self.sync_page), ConvertPage(self), InfoPage(self)]
        self.tabs = QTabWidget()
        for page, title in zip(self.pages, ("Sync Album", "Combine Tracks", "Convert", "File Info")):
            self.tabs.addTab(page, title)

        self.status = QLabel("Choose a tool above to get started.")
        self.status.setWordWrap(True)
        self.status.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        self.progress = QProgressBar()
        self.progress.setRange(0, 1000)
        self.progress.setTextVisible(False)
        self.progress.setStyleSheet(PROGRESS_STYLE)

        self.details_button = QPushButton("Show Details")
        self.details_button.setCheckable(True)
        self.details_button.toggled.connect(self._toggle_details)
        self.play_button = QPushButton("Play")
        self.play_button.clicked.connect(lambda: open_file(self._job_output))
        self.folder_button = QPushButton("Show in Folder")
        self.folder_button.clicked.connect(lambda: show_in_folder(self._job_output))
        self.cancel_button = QPushButton("Cancel")
        self.cancel_button.clicked.connect(self.cancel_job)
        buttons = QHBoxLayout()
        buttons.addWidget(self.details_button)
        buttons.addStretch()
        for button in (self.play_button, self.folder_button, self.cancel_button):
            button.hide()
            buttons.addWidget(button)

        self.log = QPlainTextEdit()
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(3000)
        self.log.setFont(QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont))
        self.log.setFixedHeight(170)
        self.log.hide()

        panel = QFrame()
        panel.setFrameShape(QFrame.Shape.StyledPanel)
        panel_layout = QVBoxLayout(panel)
        panel_layout.addWidget(self.status)
        panel_layout.addWidget(self.progress)
        panel_layout.addLayout(buttons)
        panel_layout.addWidget(self.log)

        central = QWidget()
        layout = QVBoxLayout(central)
        layout.addWidget(self.tabs, 1)
        layout.addWidget(panel)
        self.setCentralWidget(central)

    def start_job(self, title: str, args: list[str], expected_seconds: Callable[[], float | None], output: str,
                  on_success: Callable[[str], str | None] | None = None):
        """Run ffmpeg in the background; on_success may return a status message to show."""
        self._job_title, self._job_output, self._on_success = title, output, on_success
        self.log.clear()
        self.tabs.setEnabled(False)
        self.play_button.hide()
        self.folder_button.hide()
        self.cancel_button.setEnabled(True)
        self.cancel_button.show()
        self.progress.setRange(0, 0)
        self.status.setText(f"{title}... getting ready")

        self.job = FFmpegJob(self.ffmpeg, args, expected_seconds, output, self)
        self.job.progress.connect(self._on_progress)
        self.job.log_line.connect(self.log.appendPlainText)
        self.job.done.connect(self._on_done)
        self.job.start()

    def cancel_job(self):
        if self.job:
            self.cancel_button.setEnabled(False)
            self.status.setText("Stopping...")
            self.job.cancel()

    def _on_progress(self, fraction: float, remaining: float | None):
        if fraction < 0:
            self.progress.setRange(0, 0)
            self.status.setText(f"{self._job_title}...")
            return
        self.progress.setRange(0, 1000)
        self.progress.setValue(int(fraction * 1000))
        text = f"{self._job_title}... {fraction:.0%}"
        if remaining is not None and fraction > 0.01:
            text += f"  ·  about {describe_time(remaining)} left"
        self.status.setText(text)

    def _on_done(self, success: bool, message: str):
        self.tabs.setEnabled(True)
        self.cancel_button.hide()
        self.progress.setRange(0, 1000)
        self.progress.setValue(1000 if success else 0)
        if not success:
            self.status.setText(message)
            if message != "Cancelled.":
                self.details_button.setChecked(True)
            return
        text = f"Done! Saved {os.path.basename(self._job_output)}"
        if self._on_success:
            text = self._on_success(self._job_output) or text
        self.status.setText(text)
        self.play_button.show()
        self.folder_button.show()

    def _toggle_details(self, shown: bool):
        self.log.setVisible(shown)
        self.details_button.setText("Hide Details" if shown else "Show Details")

    def closeEvent(self, event):
        if self.job and self.job.isRunning():
            answer = QMessageBox.question(self, APP_NAME, "ffmpeg is still working. Stop it and quit?")
            if answer != QMessageBox.StandardButton.Yes:
                event.ignore()
                return
            self.job.cancel()
            self.job.wait(10_000)
        for page in self.pages:
            page.save_settings()
        event.accept()


def main() -> int:
    if os.name == "nt":
        import ctypes
        # Use the app's own icon in the taskbar instead of Python's
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("MovieAlbumSync.App")

    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    app.setApplicationVersion(__version__)
    app.setWindowIcon(QIcon(str(resource_path("assets/icon.ico"))))
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.Highlight, QColor(ACCENT))
    palette.setColor(QPalette.ColorRole.Accent, QColor(ACCENT))
    palette.setColor(QPalette.ColorRole.HighlightedText, QColor("white"))
    app.setPalette(palette)
    clean_temp_files()

    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        QMessageBox.critical(None, APP_NAME, "ffmpeg couldn't be found, so the app can't run.\n\n"
                                             "Reinstall Movie Album Sync, or install ffmpeg and try again.")
        return 1

    window = MainWindow(ffmpeg)
    window.show()
    return app.exec()
