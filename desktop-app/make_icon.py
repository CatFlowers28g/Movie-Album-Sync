"""Draws the app icon and saves it as assets/icon.ico and assets/icon.png.

Only needed when changing the icon: python make_icon.py
"""

from pathlib import Path

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QBrush, QColor, QFont, QGuiApplication, QImage, QLinearGradient, QPainter

SIZE = 256
ASSETS = Path(__file__).resolve().parent / "assets"


def draw() -> QImage:
    image = QImage(SIZE, SIZE, QImage.Format.Format_ARGB32)
    image.fill(Qt.GlobalColor.transparent)
    painter = QPainter(image)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)

    # Purple rounded square
    gradient = QLinearGradient(QPointF(0, 0), QPointF(SIZE, SIZE))
    gradient.setColorAt(0, QColor("#8B5CF6"))
    gradient.setColorAt(1, QColor("#5B21B6"))
    painter.setPen(Qt.PenStyle.NoPen)
    painter.setBrush(QBrush(gradient))
    painter.drawRoundedRect(QRectF(8, 8, SIZE - 16, SIZE - 16), 52, 52)

    # Film-strip sprocket holes along the top and bottom
    painter.setBrush(QColor(255, 255, 255, 90))
    for x in range(36, SIZE - 36, 34):
        painter.drawRoundedRect(QRectF(x, 26, 18, 14), 4, 4)
        painter.drawRoundedRect(QRectF(x, SIZE - 40, 18, 14), 4, 4)

    # Music note
    painter.setPen(QColor("white"))
    font = QFont("Segoe UI Symbol")
    font.setPixelSize(150)
    painter.setFont(font)
    painter.drawText(QRectF(0, 6, SIZE, SIZE), Qt.AlignmentFlag.AlignCenter, "♫")
    painter.end()
    return image


if __name__ == "__main__":
    app = QGuiApplication([])
    ASSETS.mkdir(exist_ok=True)
    icon = draw()
    icon.save(str(ASSETS / "icon.png"))
    icon.save(str(ASSETS / "icon.ico"))
    print(f"Saved icon to {ASSETS}")
