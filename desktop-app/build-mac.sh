#!/usr/bin/env bash
# Builds the Mac download for Movie Album Sync, for the chip of the Mac it runs on:
#   dist/MovieAlbumSync-<version>-Mac-AppleSilicon.dmg   (on an M1-M4 Mac)
#   dist/MovieAlbumSync-<version>-Mac-Intel.dmg          (on an Intel Mac)
#
# Usage: bash build-mac.sh   (on a Mac with Python 3, or in GitHub Actions)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$HOME/Library/Caches/MovieAlbumSync-build"
VENV="$WORK/venv"
PYTHON="$VENV/bin/python"
VERSION=$(sed -n 's/^__version__ = "\(.*\)"/\1/p' "$ROOT/movie_album_sync/__init__.py")
APP_NAME="Movie Album Sync"

case "$(uname -m)" in
    arm64)  CHIP=AppleSilicon; FFMPEG_ARCH=arm64 ;;
    x86_64) CHIP=Intel;        FFMPEG_ARCH=amd64 ;;
    *) echo "Unsupported Mac chip: $(uname -m)"; exit 1 ;;
esac
FFMPEG_DIR="$WORK/ffmpeg-$FFMPEG_ARCH"

echo "Building $APP_NAME $VERSION for $CHIP Macs"
mkdir -p "$WORK"

# 1. Python environment (Pillow lets PyInstaller turn the PNG icon into a Mac .icns)
[ -x "$PYTHON" ] || python3 -m venv "$VENV"
"$PYTHON" -m pip install --disable-pip-version-check -q -r "$ROOT/requirements.txt" -r "$ROOT/requirements-build.txt" pillow

# 2. Tests
echo "Running tests..."
(cd "$ROOT" && "$PYTHON" -m unittest discover -s tests -q)

# 3. ffmpeg: the newest release build for this chip from ffmpeg.martin-riedl.de (includes x264/x265)
if [ ! -x "$FFMPEG_DIR/ffmpeg" ]; then
    download=$(curl -fsSL https://ffmpeg.martin-riedl.de/ \
        | grep -oE "/download/macos/$FFMPEG_ARCH/[0-9]+_[0-9]+\.[0-9.]+/ffmpeg\.zip" | sort -t/ -k5 -n | tail -1)
    [ -n "$download" ] || { echo "Couldn't find an ffmpeg download for $FFMPEG_ARCH"; exit 1; }
    echo "Downloading ffmpeg from https://ffmpeg.martin-riedl.de$download ..."
    mkdir -p "$FFMPEG_DIR"
    curl -fsSL "https://ffmpeg.martin-riedl.de$download" -o "$WORK/ffmpeg.zip"
    unzip -o -q "$WORK/ffmpeg.zip" -d "$FFMPEG_DIR"
    rm "$WORK/ffmpeg.zip"
    chmod +x "$FFMPEG_DIR/ffmpeg"
    "$FFMPEG_DIR/ffmpeg" -hide_banner -L > "$FFMPEG_DIR/LICENSE.txt"
fi

# 4. App bundle with PyInstaller
echo "Packaging the app..."
"$PYTHON" -m PyInstaller --noconfirm --clean --windowed --log-level WARN \
    --name "$APP_NAME" \
    --osx-bundle-identifier com.catflowers28g.movie-album-sync \
    --icon "$ROOT/assets/icon.png" \
    --add-data "$ROOT/assets/icon.ico:assets" \
    --add-binary "$FFMPEG_DIR/ffmpeg:ffmpeg" \
    --add-data "$FFMPEG_DIR/LICENSE.txt:ffmpeg" \
    --distpath "$WORK/dist" --workpath "$WORK/pyinstaller" --specpath "$WORK" \
    "$ROOT/launch.py"
APP="$WORK/dist/$APP_NAME.app"

# Version shown in Finder's Get Info; re-sign (ad hoc) since editing Info.plist breaks the signature
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"

# 5. Make sure the packaged app starts and can run its ffmpeg
"$APP/Contents/MacOS/$APP_NAME" --self-test

# 6. Disk image with the app and an Applications shortcut to drag it onto
mkdir -p "$ROOT/dist"
DMG="$ROOT/dist/MovieAlbumSync-$VERSION-Mac-$CHIP.dmg"
STAGE="$WORK/dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
echo "Disk image: $DMG"
