#!/bin/bash
# Compile AppleScript files into .app bundles
# Usage: bash compile-apps.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="$HOME/Applications"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Compiling AppleScript files to .app bundles..."
echo "Output directory: $OUTPUT_DIR"
echo ""

# Array of AppleScript files and their corresponding app names
declare -a apps=(
    "01-Movie-Sync-Audio.applescript:Movie Sync Audio"
    "02-FFmpeg-Info-Logger.applescript:FFmpeg Info Logger"
    "03-FLAC-Combiner.applescript:FLAC Combiner"
    "04-Test-Clip-Extractor.applescript:Test Clip Extractor"
    "05-Video-Audio-Reencoder.applescript:Video Audio Re-Encoder"
)

# Compile each app
for app in "${apps[@]}"; do
    IFS=':' read -r script_file app_name <<< "$app"
    script_path="$SCRIPT_DIR/$script_file"
    app_path="$OUTPUT_DIR/$app_name.app"
    
    if [ ! -f "$script_path" ]; then
        echo "❌ Error: $script_path not found!"
        continue
    fi
    
    echo "Compiling: $script_file -> $app_name.app"
    
    # Remove existing app if it exists
    if [ -d "$app_path" ]; then
        rm -rf "$app_path"
    fi
    
    # Compile using osacompile
    osacompile -l AppleScript -o "$app_path" "$script_path"
    
    if [ -d "$app_path" ]; then
        echo "✅ Successfully created: $app_path"
    else
        echo "❌ Failed to create: $app_path"
    fi
    echo ""
done

echo "All apps compiled!"
echo "You can find them in: $OUTPUT_DIR"
echo ""
echo "To use these apps:"
echo "1. Open Finder and navigate to $OUTPUT_DIR"
echo "2. Double-click any .app to run it"
echo "3. The app will guide you through file selection and parameter input"
