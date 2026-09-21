# Component Deep Dives

## batch-backup

Four run modes. The core workhorse of the pipeline.

```mermaid
flowchart TD
    LAUNCH([batch-backup called]) --> ENV[set HOME + PATH
widget safety guard]
    ENV --> SRC[source .bashrc OR true
prevents set -e silent exit]
    SRC --> PRE[preflight
zip python3 jq termux-dialog]
    PRE --> PARSE[parse segments_data.json
build SEG_NAMES + SEG_COUNTERS]
    PARSE --> MODE{argument?}

    MODE -->|--hot| HOT[segments counter gte 50
auto-targets no dialog]
    MODE -->|--all| ALL[all segment-matched
folders no dialog]
    MODE -->|--unzipped| UNZ[folders with
no zip yet]
    MODE -->|none| DLG[termux-dialog checkbox
all shared/ folders]

    DLG -->|Samsung values field| VPARSE[parse values text field
strip annotations]
    DLG -->|standard index field| IPARSE[jq .index
validate bounds]
    DLG -->|text fallback| TPARSE[jq .text
trim + match labels]
    DLG -->|code -2| CANCEL([exit 0 cancelled])

    HOT & ALL & UNZ --> TARGETS
    VPARSE & IPARSE & TPARSE --> TARGETS

    TARGETS[deduplicate
filter blanks] --> LOOP

    subgraph LOOP [zip loop]
        F[for each folder] --> HZ{has existing zip?}
        HZ -->|no| ZB[z_backup direct
new timestamped zip]
        HZ -->|yes| PROMPT[prompt
m merge / a append / s skip]
        PROMPT -->|merge| MRG[extract + combine
re-zip merged_timestamp.zip
delete old zip]
        PROMPT -->|append| APP[z_backup
new zip alongside existing]
        PROMPT -->|skip| SKIP[leave untouched]
        ZB & MRG & APP & SKIP --> NEXT{more?}
        NEXT -->|yes| F
        NEXT -->|no| SUMMARY
    end

    SUMMARY[print summary
PASS FAIL counts] --> PARITY[parity report
unbacked segments]
```

**Known issue:** checkbox dialog (`none` mode) confirmed showing on ZFlip7 but
selection not zipping. Root cause: Samsung returns
`values: [{index:N, text:"name"}]` not a flat array. Fix in v3: `parse values text field`.
Status: deployed, awaiting test confirmation. *(Not reviewed this session --
`batch-backup`'s source hasn't been shared, so this status is carried over
unverified.)*

**Merge/append/skip** -- tested and working on ZFlip7. When a folder already
has a zip in Export/, you are prompted:
- `m` merge: extract + combine files + re-zip as single archive
- `a` append: new timestamped zip alongside existing (default)
- `s` skip: leave existing untouched

---

## segment_manager

Python REPL. The counter drives `--hot` targeting in batch-backup passively.

**Corrected this pass:** the clipboard used to output a `<segment><counter>`
title line plus platform-tailored hashtag sets. Both were removed: the
clipboard now copies **hashtags only**, straight from the segment's own
`hashtags` list in `segments_data.json`, with no platform branching and no
title line -- system state lives entirely in that one JSON schema, not
duplicated per output target.

```mermaid
flowchart TD
    LAUNCH2([segment_manager.py]) --> LOAD[load segments_data.json]
    LOAD --> QMODE{--quick flag?}
    QMODE -->|yes| QUICK[show hot segments
1 input
clipboard ready]
    QMODE -->|no| MENU

    subgraph MENU [main REPL loop]
        M0[print menu
sorted by counter] --> INPUT{choice}
        INPUT -->|1| SEARCH[search and copy]
        INPUT -->|2| QUICK2[quick copy hot]
        INPUT -->|3| ADD[add series]
        INPUT -->|4| EDIT[edit series]
        INPUT -->|5| DELETE[delete series]
        INPUT -->|6| LIST[list all]
        INPUT -->|7| BULK[bulk counter update]
        INPUT -->|8| STATS[stats dashboard]
        INPUT -->|9| TREND[trend ideas]
        INPUT -->|q| QUIT([exit])
        SEARCH & QUICK2 & ADD & EDIT & DELETE & BULK --> SAVE[save_data
counter++]
        SAVE --> M0
    end

    SEARCH & QUICK2 & BULK --> COPY[copy_to_clipboard
hashtags only, one line]
```

**Real `segments_data.json` schema** (list, not a dict keyed by name):

```json
{
  "segments": [
    {
      "id": 19,
      "name": "pistol",
      "short_desc": "pistol squats",
      "full_desc": "pistol squats",
      "counter": 555,
      "hashtags": ["#squats", "#pistolsquats", "#legs", "#calisthenics", "#core"]
    }
  ]
}
```

Every script in the pipeline that touches segment data (`burn_thumb.sh`,
`mkshot_burn`, `org-camera-album-burn.sh`, `seg_add`/`seg_set_counter`/
`seg_bump` in `.bashrc`) matches against this list-by-`name` shape, not a
dict keyed by segment name -- an earlier draft of the burn tooling guessed
wrong on this and had to be corrected once the real file was shared.

---

## z_backup internals

```mermaid
flowchart TD
    IN([z_backup folder]) --> BIN[locate zip binary
full Termux path
fallback command -v]
    BIN -->|not found| FAIL([exit 1
pkg install zip])
    BIN -->|found| RES[resolve src
shared/ first
then DCIM/]
    RES -->|not found| FAIL2([exit 1])
    RES -->|found| EMPTY{ls -A src
empty?}
    EMPTY -->|yes| SKIP2([return 0
SKIPPED])
    EMPTY -->|no| ZIP[cd src
zip -9 -r zip_path .]
    ZIP -->|exit 0| SIZE[print size + path]
    ZIP -->|fail| CLEAN[rm partial
return 1]
```

**Why `zip -r .` not `zip *`:**
The `*` glob fails on empty dirs, skips subdirectories, and errors on
filenames with spaces. `zip -9 -r "$zip_path" .` recurses everything
unconditionally. Exit code 127 = zip binary not in PATH -- fix: `pkg install zip`.

---

## org-camera-album

**Corrected this pass.** The previous version of this doc described a
smart radio-dialog router (hot segments sorted to the top, one-tap
routing, marked "tested" in the changelog). Once the actual script was
shared, that turned out not to match reality -- the real `org-camera-album`
is simpler and **not segment-aware at all**:

```mermaid
flowchart TD
    LAUNCH3([org-camera-album]) --> CHECK{DCIM/Camera
exists?}
    CHECK -->|no| FAIL3([exit 1
run termux-setup-storage])
    CHECK -->|yes| DIALOG[termux-dialog text
prompt: Enter NEW folder name]
    DIALOG -->|empty| EXIT2([exit 0
nothing entered])
    DIALOG -->|name entered| MKDIR[mkdir -p
shared/name]
    MKDIR --> MOVE[find + xargs mv
mp4/mov/3gp/webm/mkv/jpg/jpeg/png]
    MOVE --> SCAN[termux-media-scan -r
source + destination]
    SCAN --> DONE2([done])
```

It's a free-text prompt for **any** folder name -- new or existing, no
awareness of `segments_data.json`, no counter, no hot-segment sorting. The
segment-aware, counter-tracking variants are `mkshot`/`mkshot_burn` in
`.bashrc` and the standalone `org-camera-album-burn.sh` (see next section) --
those are newer additions layered alongside the original script, not a
replacement for it.

**v4 proposed -- org-collect:** Extends this to pull from 6 sources
(DCIM, Instagram Edits, Quick Share, Downloads, Screenshots, CapCut)
in a single pass, reading destination from `session.json`. Unchanged from
the original proposal; still not built.

---

## burn_thumb.sh / mkshot_burn / org-camera-album-burn

New this session. Burns a sequential text label ("Pistol 554") onto the
first few seconds of each clip in a segment, using `ffmpeg`'s `drawtext`
filter, and keeps `segments_data.json`'s counter in sync automatically.

**Three entry points, one shared core:**

| Entry point | Where | What it does |
|---|---|---|
| `burn_thumb` (`burnthumb`) | `burn_thumb.sh` | Single file, reads label from `session.json` or prompts |
| `burn_thumb_segment` (`burnthumbsegment`) | `burn_thumb.sh` | Batch-burns an already-populated folder |
| `mkshot_burn` (`mksb`) | `.bashrc` | Moves DCIM/Camera into a segment folder **and** burns in one step |
| `org-camera-album-burn.sh` | standalone script | Same as `mkshot_burn`, styled like the original `org-camera-album` (jq-parsed dialog, `set -x`) |

All four call the same `_burn_thumb_core` function, sourced once from
`burn_thumb.sh` -- `.bashrc` no longer keeps its own copy. That
consolidation happened *because* duplicating it caused real bugs: fixes
applied to one copy didn't propagate to the other, and it took a couple of
rounds to notice.

```mermaid
flowchart TD
    LAUNCH4([mkshot-burn segment]) --> LOOKUP[look up segment
in segments_data.json]
    LOOKUP -->|not found| FAIL4([exit 1
add with seg-add first])
    LOOKUP -->|found| CAPTURE[capture exact file list
from DCIM/Camera
excludes hidden dotfiles]
    CAPTURE --> CONFIRM{move N files
and burn labels?}
    CONFIRM -->|n| CANCEL2([cancelled])
    CONFIRM -->|y| MOVELOOP[move each file by name]

    MOVELOOP --> BURNLOOP{already
_labeled?}
    BURNLOOP -->|yes| SKIPLBL[move only,
don't re-burn]
    BURNLOOP -->|no, video ext| CORE

    subgraph CORE [_burn_thumb_core]
        FONT{font found?
Roboto / DroidSans / DejaVu}
        FONT -->|none| FAILFONT([fail loud,
suggest pkg install])
        FONT -->|found| ENCODE[ffmpeg -nostdin lt /dev/null
drawtext, timeout 180s
-stats piped live via tee]
        ENCODE -->|success| OK4[counter++]
        ENCODE -->|fail or timeout| SKIP4[print ffmpeg's real
error tail, skip,
counter rolled back,
continue -- not break]
    end

    OK4 & SKIP4 & SKIPLBL --> WRITEBACK[write counter back to
segments_data.json in place]
    WRITEBACK --> DONE4([done: moved M, labeled N])
```

**Style:** centered on frame, fontsize 120, 6px black border (not the
original bottom-third drop-shadow style).

---

## tapestry / sandwich / video-utils.sh

Originally one dual-mode script (`--concat`/`--grid`); split into two
single-purpose tools after concat (the default mode) produced the wrong
output when the goal was a grid -- one flag you had to remember to pass
was one too many failure modes.

- **`tapestry`** -- NxN grid, all clips playing simultaneously (e.g. "100
  pistol squats in 30 seconds" style posts). Output resolution is
  configurable (`--width`/`--height`, or `--vertical`/`--square`/
  `--landscape` shortcuts) and *forced* to exactly match the target via a
  trailing `scale` filter -- cell size used to be hardcoded at 480x270
  regardless of `--cols`, so the grid never actually filled a phone screen
  when played back.
- **`sandwich`** -- sequential concatenation into one long reel. This is
  the tool for turning a folder of short clips into continuous long-format
  content.
- **`video-utils.sh`** -- shared library both source: clip collection
  (case-insensitive extensions, dotfile exclusion), upfront `ffprobe`
  validation (one corrupt clip no longer takes down a whole grid/concat
  job), numeric-flag sanitizing, and the `-nostdin`/timeout ffmpeg-safety
  pattern established in `burn_thumb.sh`.

```mermaid
flowchart TD
    LAUNCH5([tapestry OR sandwich <segment>]) --> PARSE5[parse args
index-based, not shift-in-loop]
    PARSE5 --> GUARD5{cols/max/timeout/
width/height valid?}
    GUARD5 -->|no| DEFAULT5[warn, fall back
to defaults]
    GUARD5 -->|yes| COLLECT5[collect_clips
video-utils.sh: shared]
    DEFAULT5 --> COLLECT5

    COLLECT5 --> VALIDATE5[ffprobe each clip
shared by both scripts]
    VALIDATE5 -->|corrupt| WARN5[warn + skip]
    VALIDATE5 -->|valid| CLIPLIST5[CLIPS array]

    CLIPLIST5 --> MODE5{which script?}
    MODE5 -->|tapestry| GRID5[xstack filter
cell size derived from
target width/height]
    MODE5 -->|sandwich| CONCAT5[concat demuxer]

    GRID5 --> FORCE5[trailing scale filter:
force exact target resolution]
    CONCAT5 & FORCE5 -->|timeout| TIMEOUT5([killed, reported,
raise --timeout])
    CONCAT5 & FORCE5 -->|success| SAVE5[Export/segment_
tapestry-or-sandwich_timestamp.mp4]
```

Corrected/hardened this pass: case-sensitive extension matching (`.MP4` was
invisible), no clip validation in grid mode, no timeout protection,
`--cols 0` divide-by-zero, malformed numeric flags crashing instead of
falling back, `--help` as the first argument being swallowed as a segment
name, and the grid-doesn't-fill-the-screen sizing bug. All verified against
a stubbed ffmpeg/ffprobe harness, including a deliberately-hung ffmpeg
confirming the timeout kills it in the configured time rather than the
full hang duration.

---

## hwbench

The benchmark harness has its own doc: [hwbench](hwbench.md) --
test-matrix design, the MediaCodec reliability question, and the
[hwbench2](../) 3-SoC experiment extension.
