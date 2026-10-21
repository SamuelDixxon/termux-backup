#!/data/data/com.termux/files/usr/bin/bash
# SUMMARY: Shared ffmpeg helpers for tapestry/sandwich (library, not run directly)
# GROUP: media
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

# Friendly source names for the clip tools (sandwich, tapestry).
# Anything else falls through to $SHARED/<name> exactly as before.
resolve_clip_source() {
    local name="$1" p
    case "$name" in
        camera) echo "$SHARED/DCIM/Camera"; return ;;
        screenshots)
            for p in "$SHARED/DCIM/Screenshots" "$SHARED/Pictures/Screenshots"; do
                [ -d "$p" ] && { echo "$p"; return; }
            done
            echo "$SHARED/DCIM/Screenshots"; return ;;
        downloads|download) echo "$SHARED/Download"; return ;;
        edits|edit)
            # Movies/Edits first: confirmed Meta Edits app export path
            for p in "$SHARED/Movies/Edits" "$SHARED/Edits" "$SHARED/DCIM/Edits"; do
                [ -d "$p" ] && { echo "$p"; return; }
            done
            echo "$SHARED/Movies/Edits"; return ;;
        muse) echo "$SHARED/DCIM/Muse"; return ;;
        *) echo "$SHARED/$name"; return ;;
    esac
}

# Interactive source picker for the clip tools (no-arg / widget taps).
# Radio dialog over the named sources (with clip counts) plus any segment
# folder under shared/ holding videos. Echoes the chosen source key.
pick_segment_interactive() {
    local opts="" title="Sandwich which source?" key p n d base
    for key in camera screenshots downloads edits muse; do
        p=$(resolve_clip_source "$key" 2>/dev/null) || continue
        [ -d "$p" ] || continue
        n=$(find "$p" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.3gp" -o -iname "*.webm" -o -iname "*.mkv" \) 2>/dev/null | wc -l | tr -d ' ')
        opts="${opts:+$opts,}$key"
        title="$title ($key: $n)"
    done
    for d in "$SHARED"/*/; do
        [ -d "$d" ] || continue
        base=$(basename "$d")
        case "$base" in
            DCIM|Download|Android|Export|Movies|Pictures|Music|Documents|.*) continue ;;
        esac
        n=$(find "$d" -maxdepth 2 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.3gp" -o -iname "*.webm" -o -iname "*.mkv" \) 2>/dev/null | wc -l | tr -d ' ')
        [ "$n" -eq 0 ] && continue
        opts="${opts:+$opts,}$base"
    done
    [ -z "$opts" ] && { echo "x no clip sources found"; exit 1; }
    echo "  [waiting on dialog] Pick source for sandwich -- check the popup on your screen" >&2
    local pick
    pick=$(termux-dialog radio -v "$opts" -t "$title" | jq -r '.text // ""')
    [ -z "$pick" ] && { echo "No source chosen. Exiting."; exit 0; }
    echo "$pick"
}

# Sets SRC. Exits 1 with usage/error message if segment arg or folder is bad.
require_segment_folder() {
    local segment="$1" usage="$2"
    if [ -z "$segment" ]; then
        echo -e "\n${RED}${usage}${RESET}\n"
        exit 1
    fi
    SRC="$(resolve_clip_source "$segment")"
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
        find "$SRC" -maxdepth 2 -type f -not -name ".*" -not -path "*/.*/*" \
            \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.3gp" -o -iname "*.webm" -o -iname "*.mkv" \) \
            2>/dev/null | sort | head -"$max"
    )

    # Prefer labeled versions: the burn workflow writes X_labeled.<ext> and
    # stashes the raw X.<ext> in .burned_originals/. If a labeled copy exists,
    # the same-named unlabeled file is that clip pre-burn -- drop it so
    # reels/grids don't play everything twice.
    if [ "${#__candidates[@]}" -gt 0 ]; then
        local -A __labeled_base=()
        local __bn
        for clip in "${__candidates[@]}"; do
            __bn="$(basename "$clip")"
            case "$__bn" in
                *_labeled.*) __labeled_base["${__bn%_labeled.*}"]=1 ;;
            esac
        done
        if [ "${#__labeled_base[@]}" -gt 0 ]; then
            local __deduped=()
            for clip in "${__candidates[@]}"; do
                __bn="$(basename "$clip")"
                case "$__bn" in
                    *_labeled.*) __deduped+=("$clip") ;;
                    *) [ -z "${__labeled_base[${__bn%.*}]:-}" ] && __deduped+=("$clip") ;;
                esac
            done
            __candidates=("${__deduped[@]}")
        fi
    fi

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
