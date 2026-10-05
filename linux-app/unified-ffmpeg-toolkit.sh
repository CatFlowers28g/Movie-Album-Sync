#!/usr/bin/env bash
# Unified FFmpeg Toolkit (Linux)
# Linux version of applescript-apps/00-Unified-FFmpeg-Toolkit.applescript.
# Shows zenity dialogs, then runs ffmpeg in a new terminal window.
# Usage: bash unified-ffmpeg-toolkit.sh   (or run install.sh to add it to the app menu)

set -u

APP_TITLE="Unified FFmpeg Toolkit"
VIDEO_FILTER=(--file-filter="Video files | *.mp4 *.mkv *.mov" --file-filter="All files | *")
TRANSCODE_FILTER=(--file-filter="Video files | *.mp4 *.mkv *.mov *.m4v" --file-filter="All files | *")
AUDIO_FILTER=(--file-filter="Audio files | *.flac *.mp3 *.wav *.m4a" --file-filter="All files | *")
MEDIA_FILTER=(--file-filter="Media files | *.mkv *.mp4 *.mov *.m4v *.avi *.webm *.flac *.mp3 *.wav *.m4a *.aac *.ogg" --file-filter="All files | *")
OFFSET_PROMPT=$'Enter audio offset in milliseconds:\n  • positive = audio starts after the video\n  • negative = audio starts before the video and black screen fills the gap\nExample: -5000 for 5 seconds early audio'

# ---------- Dialog helpers ----------

error_box() {
    zenity --error --title="$APP_TITLE" --no-markup --text="Error: $1" 2>/dev/null
}

# confirm <message> <ok label>
confirm() {
    zenity --question --title="$APP_TITLE" --no-markup --text="$1" --ok-label="$2" --cancel-label="Cancel" 2>/dev/null
}

# choose_from_list <prompt> <default> <items...>
choose_from_list() {
    local prompt=$1 default=$2 item rows=()
    shift 2
    for item in "$@"; do
        if [ "$item" = "$default" ]; then rows+=(TRUE "$item"); else rows+=(FALSE "$item"); fi
    done
    zenity --list --radiolist --title="$APP_TITLE" --text="$prompt" --column="" --column="Option" \
        --hide-header --width=420 --height=320 "${rows[@]}" 2>/dev/null
}

# ask_text <prompt> <default>
ask_text() {
    zenity --entry --title="$APP_TITLE" --text="$1" --entry-text="$2" 2>/dev/null
}

# ask_integer <prompt> <default> <error message>; fails if cancelled or not a whole number
ask_integer() {
    local value sign=""
    value=$(ask_text "$1" "$2") || return 1
    value=${value//[[:space:]]/}
    if [[ ! $value =~ ^[+-]?[0-9]+$ ]]; then
        error_box "$3"
        return 1
    fi
    [[ $value == -* ]] && sign=-
    value=${value#[+-]}
    echo "$sign$((10#$value))"
}

# pick_file <title> <filter args...>
pick_file() {
    local title=$1
    shift
    zenity --file-selection --title="$title" "$@" 2>/dev/null
}

# pick_files <title> <filter args...>; prints one path per line
pick_files() {
    local title=$1
    shift
    zenity --file-selection --multiple --separator=$'\n' --title="$title" "$@" 2>/dev/null
}

# save_file <title> <default path>
save_file() {
    zenity --file-selection --save --confirm-overwrite --title="$1" --filename="$2" 2>/dev/null
}

# ---------- ffmpeg helpers ----------

# sync_args <delay ms>: sets SYNC_ARGS to offset input 1's audio against input 0's video
sync_args() {
    local delay=$1
    if (( delay >= 0 )); then
        SYNC_ARGS=(-filter_complex "[1:a]adelay=${delay}|${delay},apad[aud]" -map 0:v -map "[aud]" -c:v copy -c:a flac)
    else
        local lead=$(( -delay )) lead_sec
        lead_sec=$(printf '%d.%03d' $(( lead / 1000 )) $(( lead % 1000 )))
        SYNC_ARGS=(-filter_complex "[0:v]tpad=start_duration=${lead_sec}:start_mode=add:color=black[v];[1:a]apad[aud]" \
            -map "[v]" -map "[aud]" -c:v libx264 -preset slow -crf 18 -c:a flac)
    fi
}

# launch_terminal <script>: opens the script in the first terminal emulator found
launch_terminal() {
    local script=$1 term
    for term in "${TERMINAL:-}" x-terminal-emulator gnome-terminal ptyxis kgx konsole xfce4-terminal mate-terminal tilix kitty alacritty xterm; do
        [ -n "$term" ] && command -v "$term" >/dev/null 2>&1 || continue
        case $term in
            gnome-terminal|ptyxis|kgx) setsid "$term" -- "$script" ;;
            kitty)                     setsid kitty "$script" ;;
            *)                         setsid "$term" -e "$script" ;;
        esac >/dev/null 2>&1 &
        return 0
    done
    error_box "No terminal emulator found. Set the TERMINAL environment variable to your terminal's command and try again."
    return 1
}

# run_in_terminal <title> <shell command>: runs ffmpeg in a terminal that stays open so progress and errors remain visible
run_in_terminal() {
    local script
    script=$(mktemp "${TMPDIR:-/tmp}/ffmpeg-toolkit.XXXXXX") || return 1
    {
        echo '#!/usr/bin/env bash'
        echo 'rm -f -- "$0"'
        printf 'echo %q\n' "=== $1 ==="
        echo "$2"
        echo 'echo'
        echo 'read -rp "ffmpeg has finished. Review the output above, then press Enter to close this window..."'
    } > "$script"
    chmod +x "$script"
    launch_terminal "$script" || rm -f -- "$script"
}

# ---------- Tools ----------

movie_sync_audio() {
    local video audio delay output
    video=$(pick_file "Select the video file (MKV or MP4)" "${VIDEO_FILTER[@]}") || return
    audio=$(pick_file "Select the audio file (FLAC or MP3)" "${AUDIO_FILTER[@]}") || return
    delay=$(ask_integer "$OFFSET_PROMPT" 36000 "Audio offset must be a number!") || return
    output=$(save_file "Choose where to save the output file" "$(dirname "$video")/SyncedOutput.mkv") || return

    sync_args "$delay"
    local cmd
    cmd=$(printf '%q ' "$FFMPEG" -y -i "$video" -stream_loop -1 -i "$audio" "${SYNC_ARGS[@]}" -shortest "$output")
    confirm "Ready to process:"$'\n\n'"Video: $video"$'\n'"Audio: $audio"$'\n'"Delay: ${delay}ms"$'\n'"Output: $output" "Process" || return
    run_in_terminal "Movie Sync Audio" "$cmd"
}

ffmpeg_info_logger() {
    local media base log
    media=$(pick_file "Select media file (MKV, MP4, FLAC, etc)" "${MEDIA_FILTER[@]}") || return
    base=$(basename "$media")
    [[ $base == ?*.* ]] && base=${base%.*}
    log=$(save_file "Choose where to save the log file" "$(dirname "$media")/${base}_ffmpeg_log.txt") || return

    confirm "Ready to analyze:"$'\n\n'"File: $media"$'\n'"Output: $log" "Analyze" || return
    run_in_terminal "FFmpeg Info Logger" "$(printf '%q ' "$FFMPEG" -i "$media" -f null -) > $(printf '%q' "$log") 2>&1"
}

flac_combiner() {
    local selection files output list f
    selection=$(pick_files "Select FLAC files to combine (select two or more)" "${AUDIO_FILTER[@]}") || return
    mapfile -t files < <(printf '%s\n' "$selection" | sort -V)
    if (( ${#files[@]} < 2 )); then
        error_box "You must select at least 2 files!"
        return
    fi
    output=$(save_file "Choose where to save the combined file" "$(dirname "${files[0]}")/Combined.flac") || return
    list="$(dirname "$output")/flac_list.txt"

    local order=""
    for f in "${files[@]}"; do order+=$(basename "$f")$'\n'; done
    confirm "Ready to combine ${#files[@]} FLAC files in this order:"$'\n\n'"$order"$'\n'"Output: $output"$'\n'"Concat list: $list" "Combine" || return

    # ffmpeg's concat list format, with single quotes escaped as '\''
    local escaped_quote="'\\''"
    : > "$list"
    for f in "${files[@]}"; do
        printf "file '%s'\n" "${f//\'/"$escaped_quote"}" >> "$list"
    done
    run_in_terminal "FLAC Combiner" "$(printf '%q ' "$FFMPEG" -y -f concat -safe 0 -i "$list" -c:a flac "$output")"
}

test_clip_extractor() {
    local video audio minutes delay output
    video=$(pick_file "Select the video file (MKV or MP4)" "${VIDEO_FILTER[@]}") || return
    audio=$(pick_file "Select the audio file (FLAC or MP3)" "${AUDIO_FILTER[@]}") || return
    minutes=$(ask_integer "Extract first how many minutes? (default: 3):" 3 "Duration must be a number!") || return
    delay=$(ask_integer "$OFFSET_PROMPT" 36000 "Audio offset must be a number!") || return
    output=$(save_file "Choose where to save the test clip" "$(dirname "$video")/TEST_${minutes}min.mkv") || return

    sync_args "$delay"
    local cmd
    cmd=$(printf '%q ' "$FFMPEG" -y -i "$video" -stream_loop -1 -i "$audio" -t $(( minutes * 60 )) "${SYNC_ARGS[@]}" "$output")
    confirm "Ready to extract test clip:"$'\n\n'"Video: $video"$'\n'"Audio: $audio"$'\n'"Duration: $minutes minutes"$'\n'"Audio Delay: ${delay}ms"$'\n'"Output: $output" "Extract" || return
    run_in_terminal "Test Clip Extractor" "$cmd"
}

transcode_final_product() {
    local input container vcodec resolution scale height acodec output
    input=$(pick_file "Select the input video file" "${TRANSCODE_FILTER[@]}") || return
    container=$(choose_from_list "Choose output container:" mp4 mp4 mkv mov) || return
    [ -n "$container" ] || return
    vcodec=$(choose_from_list "Choose video codec:" "libx265 (HEVC)" "copy (preserve original)" "libx264 (H.264)" "libx265 (HEVC)") || return
    [ -n "$vcodec" ] || return
    resolution=$(choose_from_list "Choose resolution:" "Original" "Original" "1080p (1920x1080)" "720p (1280x720)" "480p (854x480)" "Custom (enter height)") || return
    case $resolution in
        "Custom (enter height)")
            height=$(ask_integer "Enter desired output height in pixels (e.g. 1080):" 1080 "Invalid number for height.") || return
            scale="scale=-2:$height" ;;
        1080p*) scale="scale=-2:1080" ;;
        720p*)  scale="scale=-2:720" ;;
        480p*)  scale="scale=-2:480" ;;
        *)      scale="" ;;
    esac
    acodec=$(choose_from_list "Choose audio option:" "copy (preserve original)" "copy (preserve original)" "AAC (lossy, 320k)" "ALAC (lossless)" "FLAC (lossless)") || return
    [ -n "$acodec" ] || return
    output=$(save_file "Choose where to save the output file" "$(dirname "$input")/TranscodedOutput.$container") || return

    if [[ $vcodec == copy* && -n $scale ]]; then
        confirm "You requested video copy but also a resolution change. Video will be re-encoded with libx264. Continue?" "Continue" || return
        vcodec="libx264 (H.264)"
    fi

    local args=("$FFMPEG" -y -i "$input")
    [ -n "$scale" ] && args+=(-vf "$scale")
    case $vcodec in
        copy*)    args+=(-c:v copy) ;;
        libx264*) args+=(-c:v libx264 -preset slow -crf 18) ;;
        *)        args+=(-c:v libx265 -preset slow -crf 22) ;;
    esac
    case $acodec in
        AAC*)  args+=(-c:a aac -b:a 320k) ;;
        ALAC*) args+=(-c:a alac) ;;
        FLAC*) args+=(-c:a flac) ;;
        *)     args+=(-c:a copy) ;;
    esac
    args+=(-movflags +faststart "$output")

    confirm "Ready to transcode with the following settings:"$'\n\n'"Input: $input"$'\n'"Output: $output"$'\n'"Video codec: $vcodec"$'\n'"Audio: $acodec" "Process" || return
    run_in_terminal "Transcode Final Product" "$(printf '%q ' "${args[@]}")"
}

# ---------- Main ----------

main() {
    if ! command -v zenity >/dev/null 2>&1; then
        local message="zenity is required for the dialogs. Install it with your package manager (for example: sudo apt install zenity)."
        echo "$message" >&2
        command -v notify-send >/dev/null 2>&1 && notify-send "$APP_TITLE" "$message"
        exit 1
    fi
    FFMPEG=$(command -v ffmpeg) || {
        error_box "ffmpeg was not found. Install it with your package manager (for example: sudo apt install ffmpeg), then try again."
        exit 1
    }

    local tool
    tool=$(choose_from_list "Choose a tool to run:" "Movie Sync Audio" \
        "Movie Sync Audio" "FFmpeg Info Logger" "FLAC Combiner" "Test Clip Extractor" "Transcode Final Product") || exit 0
    case $tool in
        "Movie Sync Audio")        movie_sync_audio ;;
        "FFmpeg Info Logger")      ffmpeg_info_logger ;;
        "FLAC Combiner")           flac_combiner ;;
        "Test Clip Extractor")     test_clip_extractor ;;
        "Transcode Final Product") transcode_final_product ;;
    esac
}

# Skip main when sourced, so the helpers can be loaded on their own for testing
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
