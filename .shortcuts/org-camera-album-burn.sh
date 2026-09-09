#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ORG-CAMERA-ALBUM-BURN
# =============================================================================
# Same "move everything out of DCIM/Camera" pattern as org-camera-album,
# but targeted at an existing content segment instead of an arbitrary new
# folder name: moves the files into <segment>/, then burns a sequential
# thumbnail onto each clip using segments_data.json's LIVE counter,
# updating that counter in place as it goes.
#
# STATUS: actively in use. _burn_thumb_core now fails loud (prints ffmpeg's
# real error + checks font availability up front) instead of silently
# swallowing failures -- if burns stop working again, the trace/output will
# say why instead of just going quiet.
#
# Matches org-camera-album's actual style: set -x tracing, jq-parsed
# termux-dialog, xargs mv, termux-media-scan -r on both dirs. Difference:
# the segment name has to already exist in segments_data.json (it needs a
# counter to burn against), so this uses a text prompt + jq lookup rather
# than letting you type any new folder name.
#
# DEPENDENCY: sources burn_thumb.sh for _burn_thumb_core. Adjust the path
# below if it doesn't live next to this script on your device.
# =============================================================================
set -x

# --- Configuration & Path Setup ---
SHARED_STORAGE_ROOT="$HOME/storage/shared"
SOURCE_PATH="$SHARED_STORAGE_ROOT/DCIM/Camera"
DATA_FILE="$HOME/.shortcuts/.hidden/segments_data.json"
DUR=3
# Overridable via environment since this script takes no CLI args (it's
# typically launched from a Termux widget, not a terminal): run as
# `TIMEOUT_SECS=900 bash org-camera-album-burn.sh` for longer clips.
TIMEOUT_SECS="${TIMEOUT_SECS:-600}"

BURN_THUMB_SCRIPT="$(dirname "$0")/burn_thumb.sh"
if [ -f "$BURN_THUMB_SCRIPT" ]; then
    # shellcheck source=/dev/null
    source "$BURN_THUMB_SCRIPT"
else
    echo "CRITICAL ERROR: burn_thumb.sh not found at $BURN_THUMB_SCRIPT (need _burn_thumb_core)"
    set +x
    exit 1
fi

# --- Prerequisites Check ---
if [ ! -d "$SOURCE_PATH" ]; then
  echo "Error: Source directory '$SOURCE_PATH' not found or inaccessible."
  echo "ACTION REQUIRED: Please run 'termux-setup-storage' and grant permissions."
  set +x
  exit 1
fi

if [ ! -f "$DATA_FILE" ]; then
  echo "Error: segments_data.json not found: $DATA_FILE"
  set +x
  exit 1
fi

# --- User Input ---
# Segment must already exist -- burning needs a counter to increment against.
SEGMENT_JSON=$(termux-dialog text -t "Segment name (must exist in segments_data.json)")
SEGMENT_NAME=$(echo "$SEGMENT_JSON" | jq -r '.text // ""' | tr '[:upper:]' '[:lower:]')

if [ -z "$SEGMENT_NAME" ]; then
  echo "No segment entered. Exiting gracefully."
  set +x
  exit 0
fi

COUNTER=$(jq -r --arg name "$SEGMENT_NAME" \
  '.segments[] | select(.name == $name) | .counter' "$DATA_FILE")

if [ -z "$COUNTER" ]; then
  echo "CRITICAL ERROR: Segment '$SEGMENT_NAME' not found in $DATA_FILE"
  echo "ACTION REQUIRED: add it with segment_manager.py first, or check spelling."
  set +x
  exit 1
fi

# Copy hashtags to clipboard, same as segment_manager's hashtags-only
# option -- but inline, no dependency on calling segment_manager.py.
# Reads straight from segments_data.json (must have valid JSON hashtags
# array for this segment).
HASHTAGS=$(jq -r --arg name "$SEGMENT_NAME" '.segments[] | select(.name == $name) | .hashtags | join(" ")' "$DATA_FILE")
if [ -n "$HASHTAGS" ]; then
    echo -n "$HASHTAGS" | termux-clipboard-set
    echo "Copied hashtags to clipboard: $HASHTAGS"
else
    echo "! No hashtags found for '$SEGMENT_NAME' -- clipboard untouched"
fi

# 1. Define the full path for the segment directory inside shared storage.
TARGET_PATH="$SHARED_STORAGE_ROOT/$SEGMENT_NAME"
echo "Attempting to create directory at: $TARGET_PATH"

# --- Execution: Directory Creation ---
mkdir -p "$TARGET_PATH"

if [ $? -ne 0 ]; then
    echo "CRITICAL ERROR: Failed to create target directory: $TARGET_PATH"
    set +x
    exit 1
fi

echo "SUCCESS: Directory '$TARGET_PATH' created."

# 2. Move video files using find and xargs. (Stills excluded here on purpose
#    -- burn_thumb_core is a video-only ffmpeg pass. If you want photos
#    routed into the segment folder too without labeling, tell me and I'll
#    split this into a move-all + burn-videos-only two-pass instead.)
echo "Searching for files in: $SOURCE_PATH"
find "$SOURCE_PATH" -maxdepth 1 -type f ! -name '.*' \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.3gp" -o -iname "*.webm" -o -iname "*.mkv" \) -print0 | xargs -0 mv -t "$TARGET_PATH"

# --- Gallery Refresh Step ---
echo "Moving files complete. Now refreshing the Android Media Gallery..."
termux-media-scan -r "$TARGET_PATH"
termux-media-scan -r "$SOURCE_PATH"

# --- Burn stage ---
LABEL_PREFIX="$(echo "${SEGMENT_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${SEGMENT_NAME:1}"
PROCESSED=0

# THE ACCUMULATION FIX: this loop rescans the whole TARGET_PATH folder
# every run (needed, since new files can be added between runs). Without
# relocating successfully-burned originals afterward, every re-run would
# rediscover EVERY original ever moved into this folder -- not just new
# ones -- since ! -iname '*_labeled.*' only excludes a file from matching
# itself, it does nothing to stop the file's own unlabeled ORIGINAL from
# being re-matched indefinitely. That's what caused "can only run once or
# things get overwritten": every re-run re-burned every old clip too,
# re-incrementing the counter and overwriting each _labeled output with a
# new (wrong) label number, every single time.
while IFS= read -r -d '' f; do
    COUNTER=$((COUNTER + 1))
    LABEL="${LABEL_PREFIX} ${COUNTER}"
    base=$(basename "$f" | sed 's/\.[^.]*$//')
    ext="${f##*.}"
    output="${TARGET_PATH}/${base}_labeled.${ext}"

    echo "[$LABEL] $(basename "$f")"
    if _burn_thumb_core "$f" "$output" "$LABEL" "$DUR" "$TIMEOUT_SECS"; then
        termux-media-scan "$output"
        PROCESSED=$((PROCESSED + 1))
        mkdir -p "$TARGET_PATH/.burned_originals"
        mv "$f" "$TARGET_PATH/.burned_originals/" 2>/dev/null
        
    else
        echo "burn failed on $(basename "$f") -- skipping this one, counter rolled back, continuing"
        COUNTER=$((COUNTER - 1))
    fi 
done < <(find "$TARGET_PATH" -maxdepth 1 -type f ! -name '.*' ! -iname '*_labeled.*' \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.3gp' -o -iname '*.webm' -o -iname '*.mkv' \) -print0 | sort -z)

# Update segments_data.json counter in place -- write to temp then mv,
# so a failed jq run can't leave the schema half-written.
jq --arg name "$SEGMENT_NAME" --argjson counter "$COUNTER" \
  '(.segments[] | select(.name == $name) | .counter) = $counter' \
  "$DATA_FILE" > "${DATA_FILE}.tmp" && mv "${DATA_FILE}.tmp" "$DATA_FILE"

# --- Final Confirmation ---
echo "--------------------------------------------------------"
echo "OK $SEGMENT_NAME: $PROCESSED clips labeled, counter -> $COUNTER"
echo "Files are in: $TARGET_PATH"
echo "--------------------------------------------------------"

set +x
