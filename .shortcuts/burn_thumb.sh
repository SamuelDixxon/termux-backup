# =============================================================================
# FFMPEG: THUMBNAIL BURNER
# =============================================================================
# Burn a text label onto the first N seconds of a video.
#
# TWO ENTRY POINTS:
#   burn_thumb          -- single file, reads label from session.json or prompts
#   burn_thumb_segment   -- batch mode: run against a whole segment folder
#                            (the natural next step after org-camera-album),
#                            auto-increments the counter in segments_data.json
#                            for every file it successfully processes.
#
# STYLE (per latest direction):
#   - centered on the frame (both axes)
#   - larger (fontsize 120, up from 100)
#   - bold black outline instead of drop shadow
#
# EDUCATIONAL CONCEPT:
#   drawtext filter = real-time video compositing.
#   Same technique used in broadcast lower-thirds and OSD overlays.
#   In ATE: analogous to burning a test ID onto a captured waveform image.
# =============================================================================

# -----------------------------------------------------------------------------
# _burn_thumb_core: shared ffmpeg call. Not meant to be run directly.
#   $1 input path   $2 output path   $3 label text   $4 duration (seconds)
#
# IMPORTANT: always called with -nostdin and < /dev/null. Without that,
# ffmpeg's default interactive keyboard-command listener can grab stdin
# mid-encode and drop into its "Enter command: <target>|all <time>..."
# prompt, which then blocks forever waiting for input that will never
# come in a script. That was the actual cause of encodes appearing to
# hang -- the encode itself was progressing fine right up until it did.
# -----------------------------------------------------------------------------
_burn_thumb_core() {
    local input="$1" output="$2" label="$3" dur="$4"
    local timeout_secs="${5:-180}"
    local FFMPEG="/data/data/com.termux/files/usr/bin/ffmpeg"
    [ ! -x "$FFMPEG" ] && echo "  x ffmpeg not found -- pkg install ffmpeg" && return 1

    # Font path: try system Roboto first, fall back to any available font
    local font_path="/system/fonts/Roboto-Bold.ttf"
    [ ! -f "$font_path" ] && font_path="/system/fonts/DroidSans-Bold.ttf"
    [ ! -f "$font_path" ] && font_path="/data/data/com.termux/files/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    if [ ! -f "$font_path" ]; then
        echo "  x no usable font found -- checked Roboto-Bold, DroidSans-Bold, DejaVuSans-Bold, none exist on this device"
        echo "    fix: pkg install dejavu-fonts-ttf   (or set font_path to any .ttf you actually have)"
        return 1
    fi

    # Capture ffmpeg's output for the failure tail AND stream it live via tee
    # -- fully silencing it (2>/dev/null or > log alone) means a slow encode
    # and a genuinely hung one look identical: total silence either way.
    local ffmpeg_log
    ffmpeg_log=$(mktemp)

    local TIMEOUT_BIN
    TIMEOUT_BIN=$(command -v timeout 2>/dev/null)
    [ -z "$TIMEOUT_BIN" ] && echo "    (no 'timeout' command -- pkg install coreutils for hang protection; running without one this time)"

    echo "    encoding $(basename "$input")... (timeout ${timeout_secs}s, progress below)"
    if [ -n "$TIMEOUT_BIN" ]; then
        "$TIMEOUT_BIN" "$timeout_secs" "$FFMPEG" -nostdin -i "$input" \
            -vf "drawtext=text='$label':
                 fontfile='$font_path':
                 fontsize=120:
                 fontcolor=white:
                 borderw=6:
                 bordercolor=black:
                 x=(w-text_w)/2:
                 y=(h-text_h)/2:
                 enable='between(t,0,$dur)'" \
            -c:v libx264 -preset fast -crf 22 \
            -c:a copy \
            -movflags +faststart \
            -stats -loglevel error \
            "$output" -y < /dev/null 2>&1 | tee "$ffmpeg_log"
    else
        "$FFMPEG" -nostdin -i "$input" \
            -vf "drawtext=text='$label':
                 fontfile='$font_path':
                 fontsize=120:
                 fontcolor=white:
                 borderw=6:
                 bordercolor=black:
                 x=(w-text_w)/2:
                 y=(h-text_h)/2:
                 enable='between(t,0,$dur)'" \
            -c:v libx264 -preset fast -crf 22 \
            -c:a copy \
            -movflags +faststart \
            -stats -loglevel error \
            "$output" -y < /dev/null 2>&1 | tee "$ffmpeg_log"
    fi
    local ffmpeg_exit=${PIPESTATUS[0]}

    if [ -f "$output" ]; then
        rm -f "$ffmpeg_log"
        return 0
    elif [ "$ffmpeg_exit" -eq 124 ]; then
        echo "  x timed out after ${timeout_secs}s on $(basename "$input") -- killed, moving on to the next file"
        echo "    if your clips are long, pass a bigger timeout (5th arg to _burn_thumb_core)"
        rm -f "$ffmpeg_log"
        return 1
    else
        echo "  x ffmpeg failed on $(basename "$input") -- last few lines:"
        tail -n 6 "$ffmpeg_log" | sed 's/^/    /'
        rm -f "$ffmpeg_log"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# burn_thumb: single-file mode (unchanged interface, restyled output)
#   burn-thumb ~/storage/shared/pistol/clip.mp4
#   burn-thumb ~/storage/shared/pistol/clip.mp4 --label "Pistol 181"
#   burn-thumb ~/storage/shared/pistol/clip.mp4 --dur 5
# -----------------------------------------------------------------------------
burn_thumb() {
    local input="$1"
    shift
    local label="" dur=3

    while [ $# -gt 0 ]; do
        case "$1" in
            --label) label="$2"; shift 2 ;;
            --dur)   dur="$2";   shift 2 ;;
            *)       shift ;;
        esac
    done

    [ -z "$input" ] && echo "Usage: burn-thumb <video.mp4> [--label \"Text\"] [--dur N]" && return 1
    [ ! -f "$input" ] && echo "x File not found: $input" && return 1

    # Auto-read label from session.json if not provided
    if [ -z "$label" ]; then
        local SESSION="$HOME/.shortcuts/.hidden/session.json"
        if [ -f "$SESSION" ]; then
            local seg count
            seg=$(python3 -c "import json; d=json.load(open('$SESSION')); print(d.get('segment',''))")
            count=$(python3 -c "import json; d=json.load(open('$SESSION')); print(d.get('counter',''))")
            [ -n "$seg" ] && label="$(echo "${seg:0:1}" | tr '[:lower:]' '[:upper:]')${seg:1} $count"
        fi
    fi

    [ -z "$label" ] && read -rp "Label text (e.g. Pistol 181): " label
    [ -z "$label" ] && echo "x No label provided" && return 1

    local dir base ext output
    dir=$(dirname "$input")
    base=$(basename "$input" | sed 's/\.[^.]*$//')
    ext="${input##*.}"
    output="${dir}/${base}_labeled.${ext}"

    echo "Burning label: '$label' onto first ${dur}s of video"
    echo "Output: $output"

    if _burn_thumb_core "$input" "$output" "$label" "$dur"; then
        local size
        size=$(du -sh "$output" | cut -f1)
        echo "OK $output ($size)"
        termux-media-scan "$output" 2>/dev/null
    else
        echo "x burn-thumb failed"
        return 1
    fi
}
alias burnthumb='burn_thumb'

# -----------------------------------------------------------------------------
# burn_thumb_segment: batch mode over a whole segment folder.
#
# Run this against a folder that's already populated (e.g. by mkshot). Labels
# every clip in the folder "<Segment> <N>", incrementing N from
# segments_data.json's live counter, and writes the final counter back so
# the next batch/mkshot_burn picks up where this left off.
#
#   burn-thumb-segment ~/storage/shared/pistol
#   burn-thumb-segment ~/storage/shared/pistol --mode newfolder
#   burn-thumb-segment ~/storage/shared/pistol --mode overwrite --dur 4
#
# --mode copy       (default) leaves originals untouched, writes
#                    "<name>_labeled.ext" next to each -- matches current
#                    single-file behavior, safest / most reversible.
# --mode newfolder   writes labeled copies into <folder>/upload_ready/,
#                    originals untouched. Good staging area for upload.
# --mode overwrite   labels in place (writes to a temp file, then mv's over
#                    the original only on success). Use once you trust the
#                    pipeline -- this is the eventual long-term default.
#
# Schema: segments_data.json is {"segments": [{"name", "counter", ...}, ...]}
# -- a list, matched by name, not a dict keyed by segment name.
# -----------------------------------------------------------------------------
burn_thumb_segment() {
    local folder="$1"
    shift
    local mode="copy"
    local dur=3

    while [ $# -gt 0 ]; do
        case "$1" in
            --mode) mode="$2"; shift 2 ;;
            --dur)  dur="$2";  shift 2 ;;
            *)      shift ;;
        esac
    done

    [ -z "$folder" ] && echo "Usage: burn-thumb-segment <segment_folder> [--mode copy|overwrite|newfolder] [--dur N]" && return 1
    [ ! -d "$folder" ] && echo "x Folder not found: $folder" && return 1

    local DATA="$HOME/.shortcuts/.hidden/segments_data.json"
    [ ! -f "$DATA" ] && echo "x segments_data.json not found: $DATA" && return 1

    local segment
    segment=$(basename "$folder" | tr '[:upper:]' '[:lower:]')

    local counter
    counter=$(python3 -c "
import json
d = json.load(open('$DATA'))
match = [s for s in d['segments'] if s['name'] == '$segment']
print(match[0]['counter'] if match else -1)
")
    if [ "$counter" = "-1" ]; then
        echo "x Segment '$segment' not found in segments_data.json -- add it with seg-add first"
        return 1
    fi

    local label_prefix
    label_prefix="$(echo "${segment:0:1}" | tr '[:lower:]' '[:upper:]')${segment:1}"

    local outdir="$folder"
    if [ "$mode" = "newfolder" ]; then
        outdir="${folder}/upload_ready"
        mkdir -p "$outdir"
    fi

    echo "Segment: $segment | starting counter: $counter | mode: $mode"

    local processed=0
    while IFS= read -r -d '' f; do
        counter=$((counter + 1))
        local label="${label_prefix} ${counter}"
        local base ext output
        base=$(basename "$f" | sed 's/\.[^.]*$//')
        ext="${f##*.}"

        case "$mode" in
            overwrite) output="${f}.tmp.${ext}" ;;
            newfolder) output="${outdir}/${base}.${ext}" ;;
            *)         output="${folder}/${base}_labeled.${ext}" ;;
        esac

        echo "  [$label] $(basename "$f")"
        if _burn_thumb_core "$f" "$output" "$label" "$dur"; then
            [ "$mode" = "overwrite" ] && mv "$output" "$f"
            termux-media-scan "$output" 2>/dev/null
            processed=$((processed + 1))
        else
            echo "  x failed on $(basename "$f") -- skipping this one, counter rolled back, continuing"
            counter=$((counter - 1))
        fi
    done < <(find "$folder" -maxdepth 1 -type f ! -name '.*' ! -iname '*_labeled.*' \( -iname '*.mp4' -o -iname '*.mov' \) -print0 | sort -z)

    if [ "$processed" -eq 0 ]; then
        echo "x No video files processed in $folder"
        return 1
    fi

    python3 -c "
import json
data = json.load(open('$DATA'))
for s in data['segments']:
    if s['name'] == '$segment':
        s['counter'] = $counter
        break
json.dump(data, open('$DATA','w'), indent=2)
"

    echo "OK Processed $processed files. Segment '$segment' counter now at $counter."
}
alias burnthumbsegment='burn_thumb_segment'

# =============================================================================
# NOTE: org-camera-album-burn now lives in its own file
# (org-camera-album-burn.sh), matching the real org-camera-album's standalone
# script style instead of being a sourced bash function here. Test
# burn_thumb_segment on its own first -- see that file for the pipeline
# integration once this is proven out.
# =============================================================================

