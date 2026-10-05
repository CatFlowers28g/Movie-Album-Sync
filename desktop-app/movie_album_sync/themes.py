"""Color themes: the presets, custom colors, and turning a theme into a Qt palette."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, fields

from PySide6.QtGui import QColor, QPalette

SYSTEM = "System (Windows)"
CUSTOM = "Custom"
DEFAULT_ACCENT = "#7C3AED"


@dataclass(frozen=True)
class Theme:
    background: str
    panel: str  # input fields, lists, and buttons
    text: str
    accent: str  # main buttons, progress bar, and selections
    font: str = ""  # preferred font family; empty means the system font
    icon: str = ""


# Labels for the color customizer, in display order
COLOR_FIELDS = {
    "background": "Background",
    "panel": "Panels & fields",
    "text": "Text",
    "accent": "Accent",
}

PRESET_GROUPS: dict[str, dict[str, Theme]] = {
    "Basics": {
        "Light": Theme("#F5F3FA", "#FFFFFF", "#1F1B2E", DEFAULT_ACCENT, icon="☀️"),
        "Dark": Theme("#1C1B22", "#2A2833", "#ECEAF2", "#8B5CF6", icon="🌙"),
    },
    "Pokémon": {
        "Pikachu": Theme("#1F1F1F", "#2D2B26", "#FFF4C2", "#FFCB05", "Trebuchet MS", "⚡"),
        "Charizard": Theme("#1E2A33", "#2B3B47", "#FCEBD7", "#F08030", "Trebuchet MS", "🔥"),
        "Gengar": Theme("#120E1A", "#1F1729", "#E6DAF7", "#9B59D0", "Trebuchet MS", "👻"),
        "Bulbasaur": Theme("#EAF6EE", "#FFFFFF", "#1B4332", "#2E8B57", "Trebuchet MS", "🌿"),
    },
    "Music": {
        "Grateful Dead": Theme("#101A33", "#1B2A4E", "#F7F1E3", "#E63946", "Segoe Print", "🌹"),
    },
    "Horror": {
        "Slasher": Theme("#0A0A0A", "#171010", "#E8DADA", "#C1001F", "Georgia", "🔪"),
    },
    "Movies & more": {
        "Matrix": Theme("#000000", "#06140A", "#00FF41", "#00C832", "Consolas", "💊"),
        "Synthwave": Theme("#1A0B2E", "#2A1446", "#F9E8FF", "#FF2E97", "Bahnschrift", "🌆"),
        "Tron": Theme("#05080D", "#0C1622", "#CFF8FF", "#00E5FF", "Bahnschrift", "💠"),
        "Sith": Theme("#0B0B0D", "#19191D", "#EDEDED", "#E10600", "Bahnschrift", "🔴"),
        "Jedi": Theme("#0A1124", "#15213F", "#E3EEFF", "#2E8BFF", "Bahnschrift", "🔵"),
        "Ocean": Theme("#0B2A3C", "#12384F", "#E0F4FF", "#1FB5C9", "", "🌊"),
        "Sunset": Theme("#FFF1E6", "#FFFFFF", "#4A2C2A", "#E8434B", "", "🌅"),
    },
}
PRESETS = {name: theme for group in PRESET_GROUPS.values() for name, theme in group.items()}


def mix(a: str | QColor, b: str | QColor, amount: float) -> QColor:
    """Blend from color a toward color b by amount (0-1)."""
    a, b = QColor(a), QColor(b)
    return QColor(
        round(a.red() + (b.red() - a.red()) * amount),
        round(a.green() + (b.green() - a.green()) * amount),
        round(a.blue() + (b.blue() - a.blue()) * amount),
    )


def luminance(color: str | QColor) -> float:
    """Relative luminance (WCAG), 0 for black to 1 for white."""
    def channel(value: int) -> float:
        value /= 255
        return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4
    c = QColor(color)
    return 0.2126 * channel(c.red()) + 0.7152 * channel(c.green()) + 0.0722 * channel(c.blue())


def contrast(a: str | QColor, b: str | QColor) -> float:
    """WCAG contrast ratio between two colors, from 1 to 21."""
    high, low = sorted((luminance(a), luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def text_on(color: str | QColor) -> str:
    """Black or white, whichever reads better on the given color."""
    return "#000000" if contrast(color, "#000000") >= contrast(color, "#FFFFFF") else "#FFFFFF"


def is_dark(theme: Theme) -> bool:
    return luminance(theme.background) < 0.2


def hint_color(theme: Theme) -> QColor:
    return mix(theme.text, theme.background, 0.4)


def build_palette(theme: Theme) -> QPalette:
    background, panel, text, accent = (QColor(c) for c in (theme.background, theme.panel, theme.text, theme.accent))
    dimmed = mix(text, background, 0.55)
    palette = QPalette()
    roles = {
        QPalette.ColorRole.Window: background,
        QPalette.ColorRole.WindowText: text,
        QPalette.ColorRole.Base: panel,
        QPalette.ColorRole.AlternateBase: mix(panel, text, 0.06),
        QPalette.ColorRole.Text: text,
        QPalette.ColorRole.Button: panel,
        QPalette.ColorRole.ButtonText: text,
        QPalette.ColorRole.BrightText: accent,
        QPalette.ColorRole.Highlight: accent,
        QPalette.ColorRole.HighlightedText: QColor(text_on(accent)),
        QPalette.ColorRole.Link: accent,
        QPalette.ColorRole.LinkVisited: accent,
        QPalette.ColorRole.ToolTipBase: panel,
        QPalette.ColorRole.ToolTipText: text,
        QPalette.ColorRole.PlaceholderText: mix(text, panel, 0.5),
        QPalette.ColorRole.Accent: accent,
        # Shades Fusion uses for borders and bevels
        QPalette.ColorRole.Light: mix(panel, text, 0.25),
        QPalette.ColorRole.Midlight: mix(panel, text, 0.15),
        QPalette.ColorRole.Mid: mix(panel, text, 0.3),
        QPalette.ColorRole.Dark: mix(panel, background, 0.6),
        QPalette.ColorRole.Shadow: mix(background, QColor("black"), 0.5),
    }
    for role, color in roles.items():
        palette.setColor(role, color)
    for role in (QPalette.ColorRole.WindowText, QPalette.ColorRole.Text, QPalette.ColorRole.ButtonText):
        palette.setColor(QPalette.ColorGroup.Disabled, role, dimmed)
    palette.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.Highlight, mix(accent, background, 0.5))
    return palette


def theme_to_json(theme: Theme) -> str:
    return json.dumps(asdict(theme))


def theme_from_json(text: str) -> Theme | None:
    """A saved custom theme, or None if it's missing or unreadable."""
    try:
        data = json.loads(text)
        names = {field.name for field in fields(Theme)}
        theme = Theme(**{key: value for key, value in data.items() if key in names})
    except (TypeError, ValueError):
        return None
    if not all(QColor.isValidColorName(getattr(theme, key)) for key in COLOR_FIELDS):
        return None
    return theme
