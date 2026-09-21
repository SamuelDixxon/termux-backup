# Debugging

A real debugging arc, not a feature list -- kept honest for anyone (human
or future session) who touches this code next.

Most of the real engineering here happened in `set -x` trace-driven
debugging sessions: reproduce, trace, isolate, fix, and write down the
root cause so the next person doesn't pay the same tuition.

## Known Issues Fixed

| Bug | Symptom | Fix |
|---|---|---|
| `for arg in "$@"; do ... shift ... done` | Frozen argument list desyncs from live `shift` -- second flag grabbed the wrong value (`--dur 3` came out as the literal string `"--dur"`) | Rewrote as `while [ $# -gt 0 ]` consuming `$1`/`$2` directly, in `burn_thumb`, `burn_thumb_segment`, `mkshot_burn`, `tapestry` |
| ffmpeg `2>/dev/null` | Every failure looked identical to success -- silent, no diagnostic info, indistinguishable from a hang | Capture to a log + print `tail -n 6` on failure; live progress restored via `tee` |
| ffmpeg's interactive stdin listener | Encode would progress normally, then hang forever at an `Enter command:` prompt | Added `-nostdin` and `< /dev/null` to every ffmpeg invocation |
| `break` on first burn failure | One bad clip aborted the entire batch; every clip after it silently never got processed | Changed to skip-and-continue in `burn_thumb_segment`, `mkshot_burn`, `org-camera-album-burn.sh` |
| Hidden dotfiles swept into batches | Android trash/pending files (`.20260410_233635.mp4`) have no valid moov atom, fail with a cryptic ffmpeg error | `find ... ! -name '.*'` excludes them everywhere in the burn/tapestry tooling |
| Already-labeled files re-matched | Files with `_labeled` already in the name got re-burned into `_labeled_labeled` cascades | `find ... ! -iname '*_labeled.*'` excludes them |
| Duplicated implementation | `.bashrc` kept its own copy of `_burn_thumb_core`/`tapestry`; fixes applied to one copy didn't propagate to the other | Consolidated to single source of truth per script; `.bashrc` sources/aliases instead of duplicating |
| Wrong schema guess | Early burn tooling guessed `segments_data.json` was a dict keyed by segment name; it's actually a list matched by `name` field | Corrected once the real file was shared; all burn scripts now match the real shape |
| Case-sensitive extension matching (`tapestry`) | Clips with uppercase extensions (`.MP4`) were invisible to `find` | Switched to `-iname` |
| No clip validation in grid mode (`tapestry`) | One corrupt clip failed the entire `xstack` job instead of just being skipped | Validation now runs once upfront, shared by both `--concat` and `--grid` |
| `--cols 0` | Divide-by-zero crash | Guarded, falls back to default (2) with a warning |
| Grid cell size hardcoded (480x270) | Output resolution had no relationship to `--cols` or how it'd be viewed -- grid never filled a phone screen | Cell size now derived from a configurable target resolution (default 1080x1920 vertical); a trailing `scale` filter forces the exact target regardless of integer-division rounding |
| `--help` as first argument | Swallowed as the segment name instead of showing help, in both `tapestry` and `sandwich` | Checked for `--help`/`-h` across all args before `$1` is ever assigned to `SEGMENT` |
| Malformed `--max`/`--timeout` values | `head -` (invalid) or silent bad state | Guarded, falls back to defaults with a warning |

## Conventions earned the hard way

- Never `2>/dev/null` an ffmpeg call you might need to debug.
- `-nostdin` on every ffmpeg invocation. Always.
- `while [ $# -gt 0 ]`, never `for arg in "$@"` + `shift`.
- Exclude dotfiles in every `find` over shared storage.
- New bugs go in the table above with symptom → root cause → fix. Future-you
  (and future collaborators) will thank present-you.
