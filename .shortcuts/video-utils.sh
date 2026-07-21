#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# video-utils.sh -- shared helpers for tapestry (grid) and sandwich (concat)
# =============================================================================
# Sourced by both scripts so clip collection, validation, and ffmpeg-safety
# logic (timeout, -nostdin, dotfile/corrupt exclusion) lives in exactly one
# place. Not meant to be run directly.
#
# Install alongside tapestry and sandwich in ~/.shortcuts/ -- both source it
# via "$(dirname "$0")/video-utils.sh", so it has to sit next to them.
# =============================================================================

# -- Environment guard --------------------------------------------------------
if [ -z "$HOME" ]; then
    export HOME="/data/data/com.termux/files/home"
fi
export PATH="/data/data/com.termux/files/usr/bin:$PATH"

# -- Config -------------------------------------------------------------------
SHARED="$HOME/storage/shared"
EXPORT="$SHARED/Export"
FFMPEG="/data/data/com.termux/files/usr/bin/ffmpeg"
FFPROBE="/data/data/com.termux/files/usr/bin/ffprobe"
CACHE="/data/data/com.termux/files/home/.cache/video-utils"

# -- ANSI palette (ASCII-safe) ------------------------------------------------
BOLD="\033[1m"; RESET="\033[0m"; GREEN="\033[32m"; YELLOW="\033[33m"
RED="\033[31m"; CYAN="\033[36m"; GRAY="\033[90m"

# -- Helpers ------------------------------------------------------------------
ok()   { echo -e "  ${GREEN}v${RESET}  $*"; }
fail() { echo -e "  ${RED}x${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}!${RESET}  $*"; }
info() { echo -e "  ${GRAY}$*${RESET}"; }

# -- validate_uint: sanitize a numeric flag value in place.
#    Usage: validate_uint VARNAME DEFAULT "--flag-label"
validate_uint() {
    local __name="$1" __default="$2" __label="$3"
    local __val="${!__name}"
    case "$__val" in
        ''|*[!0-9]*)
            warn "Invalid $__label value, using default ($__default)"
            printf -v "$__name" '%s' "$__default"
            ;;
    esac
}

require_ffmpeg() {
    if [ ! -x "$FFMPEG" ]; then
        fail "ffmpeg not found"
        echo -e "${YELLOW}  Fix: pkg install ffmpeg${RESET}"
        exit 1
    fi
}

# Sets SRC. Exits 1 with usage/error message if segment arg or folder is bad.
require_segment_folder() {
    local segment="$1" usage="$2"
    if [ -z "$segment" ]; then
        echo -e "\n${RED}${usage}${RESET}\n"
        exit 1
    fi
    SRC="$SHARED/$segment"
    if [ ! -d "$SRC" ]; then
        fail "Folder not found: $SRC"
        exit 1
    fi
}

# Sets TIMEOUT_BIN (empty string if not available).
detect_timeout() {
    TIMEOUT_BIN=$(command -v timeout 2>/dev/null)
    [ -z "$TIMEOUT_BIN" ] && warn "no 'timeout' command found -- pkg install coreutils for hang protection; running without one this time"
}

# Populates global CLIPS array: chronological, case-insensitive extensions,
# hidden/dotfiles excluded, each clip validated via ffprobe before inclusion
# (so one corrupt file can't take down a whole grid/concat job).
collect_clips() {
    local max="$1"
    mapfile -t __candidates < <(
        find "$SRC" -maxdepth 2 -type f -not -name ".*" \
            \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.3gp" -o -iname "*.webm" -o -iname "*.mkv" \) \
            2>/dev/null | sort | head -"$max"
    )

    if [ "${#__candidates[@]}" -eq 0 ]; then
        fail "No video files found in $SRC"
        info "Supported formats: .mp4 .mov .3gp .webm .mkv"
        exit 1
    fi

    CLIPS=()
    for clip in "${__candidates[@]}"; do
        if [ -x "$FFPROBE" ] && "$FFPROBE" -v quiet -select_streams v:0 \
            -show_entries stream=codec_name -of default=noprint_wrappers=1 \
            "$clip" 2>/dev/null | grep -q codec; then
            CLIPS+=("$clip")
        else
            warn "Skipping unreadable clip: $(basename "$clip")"
        fi
    done

    if [ "${#CLIPS[@]}" -eq 0 ]; then
        fail "No valid/readable video files in $SRC"
        exit 1
    fi
}

print_clip_list() {
    for clip in "${CLIPS[@]}"; do
        local dur=""
        if [ -x "$FFPROBE" ]; then
            dur=$("$FFPROBE" -v quiet -show_entries format=duration \
                  -of default=noprint_wrappers=1:nokey=1 "$clip" 2>/dev/null | \
                  awk '{printf "%.1fs", $1}')
        fi
        info "$(basename "$clip") $dur"
    done
}
