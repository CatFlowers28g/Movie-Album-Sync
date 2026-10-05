#!/usr/bin/env bash
# Install the Unified FFmpeg Toolkit into ~/.local/bin and add it to the desktop app menu
# Usage: bash install.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
TARGET="$BIN_DIR/unified-ffmpeg-toolkit"

mkdir -p "$BIN_DIR" "$APP_DIR"
install -m 755 "$SCRIPT_DIR/unified-ffmpeg-toolkit.sh" "$TARGET"

cat > "$APP_DIR/unified-ffmpeg-toolkit.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Unified FFmpeg Toolkit
Comment=Sync, combine, test, and transcode media with ffmpeg
Exec="$TARGET"
Icon=applications-multimedia
Terminal=false
Categories=AudioVideo;Video;Audio;
EOF

echo "✅ Installed: $TARGET"
echo "✅ App menu entry: $APP_DIR/unified-ffmpeg-toolkit.desktop"

for dependency in ffmpeg zenity; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "⚠️  $dependency is not installed. Install it with your package manager, e.g. sudo apt install $dependency"
    fi
done
