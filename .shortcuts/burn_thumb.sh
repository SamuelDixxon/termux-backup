# SUMMARY: Burn a sequential text label onto a video's first frames (thumbnail labeling)
# GROUP: media
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
#   - font size RELATIVE to frame height (1/12 of height) so the label is a
#     constant fraction of the picture on 720p, 1080p, 4K, ... -- a fixed
#     pixel size looks different on every resolution (2026-09-29 fix)
#   - bold black outline instead of drop shadow (outline also height-relative)
#   - label on the first 0.1s of display time: nearly subliminal;
#     frame 0 (the thumbnail frame) is always labeled (2026-10-11;
#     time window since 2026-11-01 -- the old frame-count window
#     scattered across display positions under B-frames)
#   - single path: full re-encode, veryfast preset (2026-11-01). The old
#     head-encode + stream-copy + concat fast path is gone: it saved
#     encoding time but carried silent-failure modes; correctness first
#   - label via textfile, not a quoted text='...' value: ffmpeg 8
#     silently renders nothing when the quoted value contains a space
#     (2026-11-01 -- "Pistol 697" drew nothing, "Pistol697" worked)
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
    local timeout_secs="${5:-600}"
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

    local FFPROBE
    FFPROBE=$(command -v ffprobe 2>/dev/null)
    [ -z "$FFPROBE" ] && FFPROBE="/data/data/com.termux/files/usr/bin/ffprobe"

    # Standardized label sizing (2026-09-29): probe the frame height and size
    # the font as a fraction of it, instead of a fixed pixel value.
    local vid_h
    vid_h=$("$FFPROBE" -v error -select_streams v:0 \
        -show_entries stream=height -of csv=p=0 "$input" 2>/dev/null | tr -d '[:space:]')
    local fontsize=120 borderw=6
    if [[ "$vid_h" =~ ^[0-9]+$ ]] && [ "$vid_h" -gt 0 ]; then
        fontsize=$(( vid_h / 12 ))
        borderw=$(( vid_h / 200 ))
        [ "$fontsize" -lt 24 ] && fontsize=24   # floor: stay legible on tiny clips
        [ "$borderw" -lt 2 ] && borderw=2
        echo "    label sizing: ${vid_h}px tall -> fontsize=${fontsize}, borderw=${borderw}"
    else
        echo "    (could not probe frame height -- falling back to fontsize=120, borderw=6)"
    fi

    # Label delivery (2026-11-01): the label goes through a textfile, NOT
    # a quoted text='...' value. ffmpeg 8 silently renders NOTHING when
    # the quoted text value contains a space ("Pistol 697" drew nothing,
    # "Pistol697" worked, exit code 0 either way) -- a quoted label is a
    # silent-failure trap. A textfile is literal: any label text, spaces
    # included, renders exactly.
    local label_file
    label_file=$(mktemp)
    printf '%s' "$label" > "$label_file"

    # Label window (2026-11-01): first 0.1s of DISPLAY time. The old
    # frames-0-2 window counted frames in decode order, which B-frames
    # scatter across display positions; a time window always covers the
    # thumbnail frame. Still nearly subliminal on playback.
    local drawtext_vf="drawtext=textfile='$label_file':fontfile='$font_path':fontsize=${fontsize}:fontcolor=white:borderw=${borderw}:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2:enable='between(t,0,0.1)'"

    # ffmpeg launcher array: timeout when available (hang protection)
    local TIMEOUT_BIN
    TIMEOUT_BIN=$(command -v timeout 2>/dev/null)
    [ -z "$TIMEOUT_BIN" ] && echo "    (no 'timeout' command -- pkg install coreutils for hang protection; running without one this time)"
    local FF=("$FFMPEG")
    [ -n "$TIMEOUT_BIN" ] && FF=("$TIMEOUT_BIN" "$timeout_secs" "$FFMPEG")

    local ffmpeg_log
    ffmpeg_log=$(mktemp)

    # Single path (2026-11-01): full re-encode, no fast path. The old
    # head-encode + stream-copy + concat fast path saved ~1min/clip but
    # carried two silent-failure modes (ffprobe field renames killed the
    # keyframe probe; a failed step could still leave a partial output
    # that counted as success). One obvious path, verified by exit code
    # AND output existence. Slower; correct. (dur stays in the signature
    # so existing callers keep working; the window above replaced it.)
    # Output is forced to 8-bit yuv420p (2026-11-01): ffmpeg 8's 10-bit
    # x264 passes 10-bit inputs straight through, and phone hardware
    # decoders cannot play 10-bit H.264 (High 10 profile) -- the file
    # decodes in software but the phone's player refuses it. 8-bit
    # High profile plays everywhere; the depth loss is invisible for
    # phone clips YouTube re-encodes anyway.
    echo "    burning \"$label\" onto $(basename "$input")... (timeout ${timeout_secs}s)"
    "${FF[@]}" -nostdin -i "$input" \
        -vf "$drawtext_vf" \
        -c:v libx264 -preset veryfast -crf 22 -pix_fmt yuv420p \
        -c:a copy \
        -movflags +faststart \
        -stats -loglevel error \
        "$output" -y < /dev/null 2>&1 | tee "$ffmpeg_log"
    local ffmpeg_exit=${PIPESTATUS[0]}
    rm -f "$label_file"

    if [ "$ffmpeg_exit" -eq 0 ] && [ -f "$output" ]; then
        echo "    OK"
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
    local label="" dur=0.25

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
#   burn-thumb-segment ~/storage/shared/pistol --timeout 900
#
# SAFE TO RE-RUN: successfully-burned originals get relocated into a
# hidden .burned_originals/ subfolder (mode copy/newfolder only -- nothing
# to relocate in overwrite mode, the original IS the output). Re-running
# this on the same folder after adding more clips only processes the new
# ones -- it used to rescan and re-burn every original ever moved in,
# re-incrementing the counter and overwriting outputs each time.
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
    local dur=0.25
    local timeout_secs=600

    while [ $# -gt 0 ]; do
        case "$1" in
            --mode)    mode="$2"; shift 2 ;;
            --dur)     dur="$2";  shift 2 ;;
            --timeout) timeout_secs="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    [ -z "$folder" ] && echo "Usage: burn-thumb-segment <segment_folder> [--mode copy|overwrite|newfolder] [--dur N] [--timeout N]" && return 1
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

    echo "Segment: $segment | starting counter: $counter | mode: $mode | timeout: ${timeout_secs}s"

    # ! -name '.*' already excludes hidden dirs like .burned_originals/ from
    # ever being descended into (maxdepth 1 doesn't recurse regardless) --
    # that's what makes the accumulation fix below actually work: once an
    # original is relocated there, it's permanently invisible to this scan.
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
        if _burn_thumb_core "$f" "$output" "$label" "$dur" "$timeout_secs"; then
            if [ "$mode" = "overwrite" ]; then
                mv "$output" "$f"
            else
                # Relocate the original out of the scan path so a future
                # re-run of this same command doesn't rediscover and
                # re-burn it -- preserved, just moved, never deleted.
                mkdir -p "$folder/.burned_originals"
                mv "$f" "$folder/.burned_originals/" 2>/dev/null
            fi
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

