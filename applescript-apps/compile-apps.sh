#!/bin/bash
# Compile the unified AppleScript app into a .app bundle
# Usage: bash compile-apps.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="$HOME/Applications"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Compiling the unified AppleScript app to a .app bundle..."
echo "Output directory: $OUTPUT_DIR"
echo ""

# Array of AppleScript files and their corresponding app names
declare -a apps=(
    "00-Unified-FFmpeg-Toolkit.applescript:Unified FFmpeg Toolkit"
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

echo "Unified app compiled!"
echo "You can find it in: $OUTPUT_DIR"
echo ""
echo "To use the app:"
echo "1. Open Finder and navigate to $OUTPUT_DIR"
echo "2. Double-click Unified FFmpeg Toolkit.app"
echo "3. Choose the tool you want and follow the prompts"
