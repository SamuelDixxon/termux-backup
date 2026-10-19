# Changelog

| Version | Date | Component | Status | Summary |
|---------|------|-----------|--------|---------|
| v4.4.7 | 2026-10 | sandwich, video-utils.sh | new | Named clip sources: `sandwich camera` (and screenshots/downloads/edits/muse) now resolve to their shared-storage folders via a new resolve_clip_source() in video-utils.sh; plain segment names work exactly as before. tapestry inherits the same aliases |
| v4.4.6 | 2026-10 | org-media | fix | Removed per-run execution logging (.hidden/org-media-runs/): the widget-debugging diagnostic served its purpose; move manifests (undo trail) retained; committed run logs deleted from the repo |
| v4.4.5 | 2026-10-14 | sync-in | fix | .bashrc deploy now compares file contents (`cmp -s`) instead of mtimes (`-nt`): every manual copy during debugging gave the live file a fresh mtime, so sync-in silently skipped all future .bashrc updates (including scheduled runs). Falls back to the old mtime check if `cmp` is unavailable |
| v4.4.4 | 2026-10 | nightly-sync, schedule-sync | new | Scheduled sync: new `nightly-sync` (sync-in then backup-all, per-run logs in .hidden/nightly-sync/, termux-notification on failure; both steps invoked via `bash` so a lost exec bit can't silently skip the run) + `schedule-sync` one-time setup registering it with termux-job-scheduler (24h, unmetered + charging, persisted). Tradeoff analysis (job-scheduler vs cronie vs Tasker) in docs/scheduling.md. Needs one on-device scheduled run to confirm |
| v4.4.3 | 2026-10 | org-media | new | edits source now prefers Movies/Edits first -- confirmed as the Meta Edits app export location on-device |
| v4.4.2 | 2026-10 | org-media | new | edits named source also checks Movies/Edits (Meta Edits app export candidate) |
| v4.4.1 | 2026-10 | tools, .bashrc | new | tools inventory skips docs/dotfiles (*.md no longer listed as tools); ~/.shortcuts added to PATH (duplicate-guarded) so `tools`, `org-media`, `backup-all`, ... run as bare commands, not just from the widget |
| v4.4 | 2026-10 | org-media | new | Multi-source: no-arg default now sweeps the four accumulation points (Camera, Edits, Muse, Screenshots); source picker is a multi-select checkbox dialog; --source accepts comma-separated keys (e.g. --source camera,edits); preview shows per-source counts; manifest records the source set; --source camera restores the strict original for pipelines |
| v4.3.3 | 2026-10 | org-media | fix | YES-on-empty-source exited the flow: the v4.3.1 '[waiting on dialog]' notice printed to stdout and polluted the captured dialog answer, so it never equaled 'yes'. Notices now go to stderr; confirm parsing also accepts any button-label case and falls back to the dialog button code |
| v4.3.2 | 2026-10 | org-media | new | Foolproof empty source: an empty default source (e.g. Camera already organized) no longer dead-ends -- shows per-source file counts and offers the source picker (up to 3 tries). Explicit --source / --yes runs keep the old exit-0 behavior for pipelines |
| v4.3.1 | 2026-10 | org-media | new | Widget hardening: dialogs now announce themselves before blocking ("[waiting on dialog] ... check the popup"), preflight check fails fast with a clear message if termux-dialog/jq are missing, and every run tees to a per-run log in .hidden/org-media-runs/ (newest 20 kept) so widget sessions that vanish on exit leave a trace |
| v4.5 | 2026-10 | burn_thumb.sh | new | Label now nearly subliminal: drawn on frames 0-2 only (~0.1s, fps-independent); frame 0 (thumbnail frame) always labeled. Old --dur time window retired (kept in signature for compatibility). Much faster: new head-only path re-encodes just the first ~1s (veryfast preset), stream-copies the rest, concats via mpegts -- a 60s clip costs ~1s of encoding. Cut lands on a real keyframe (probed); any fast-path failure falls back to full re-encode. Syntax-checked; needs one on-device test burn |
| v4.4 | 2026-10 | tools banner | new | Self-describing tool convention: every .shortcuts script now carries # SUMMARY: / # GROUP: header lines. New `tools` script renders the grouped inventory; .bashrc runs `tools --banner` on login (tool count + new/updated since last session via a seen-cache, quiet otherwise) |
| v4.3 | 2026-10 | org-media | new | Generalized org-camera-album: source picker (Camera/Screenshots/Downloads/Edits/custom path), destination picker (existing folders or new), filters (photos/videos, older-than-N-days, filename match), dated-subfolder mode, dry-run preview + confirmation, per-run move manifest. No-arg invocation behaves exactly like org-camera-album (same prompts, same move, no confirm) for backwards compatibility; one safety upgrade: existing filenames in the destination are skipped, never overwritten |
| v4.2 | 2026-10-04 | sync_history | tested | Retired the shared `sync_history.csv`: all 47 historical rows split by device into `sync_history_<device>.csv` (10 older 3-column rows padded to the 5-column schema). One source of truth going forward; full cross-device history via `cat sync_history_*.csv` |
| v4.1 | 2026-09-29 | burn_thumb.sh / mkshot_burn | tested | Label font size now relative to frame height (`fontsize=height/12`, `borderw=height/200`, floors 24/2) instead of fixed 120px -- the old absolute size rendered visibly different on 720p vs 1080p vs 4K sources. Default burn window shortened 3s to 0.25s (frame 0, the thumbnail frame, still labeled); `--dur` overrides |
| v4.0 | 2026-09-27 | backup-all | tested | Rebase-before-push (no more blind pushes / merge commits); `merge-counters` auto-resolves `segments_data.json` conflicts with max-wins per segment; sync log split per-device (`sync_history_<device>.csv`) so two phones never write the same file; 7-day purge of `.burned_originals/`; `z_backup` excludes `.burned_originals/` from zips; `GIT_EDITOR=true` for headless rebases |
| v3.5 | 2026-07 | hwbench | new | Cross-device ffmpeg hardware-vs-software benchmark harness -- N trials per path, CSV output, mean/stdev summary. Verified against a stub simulating both documented real-world MediaCodec failure modes (fast failure and the freeze-to-0-byte hang) |
| v3.4 | 2026-07 | tapestry / sandwich | tested | Split the dual-mode `tapestry` into two single-purpose scripts (`tapestry`=grid, `sandwich`=concat) sharing `video-utils.sh`. Fixed: grid output not filling the screen (cell size now derived from a configurable target resolution, forced exact via trailing scale), `--help` swallowed as a segment name when passed first |
| v3.3 | 2026-07 | tapestry | tested | Rewritten: case-insensitive extensions, upfront clip validation (both modes), `-nostdin`/timeout protection, guarded `--cols`/`--max`/`--timeout`. Verified against a stubbed ffmpeg/ffprobe harness including a deliberate hang test |
| v3.2 | 2026-07 | burn_thumb.sh / mkshot_burn | tested | New: sequential thumbnail labeling with live counter tracking. Multiple real bugs found and fixed via `set -x` trace debugging: frozen-arg-list parsing, silent ffmpeg failures, interactive-stdin hang, batch-aborting `break`, dotfile/relabel exclusion, duplicated-implementation drift |
| v3.2 | 2026-07 | .bashrc | tested | Dynamic per-segment `cd` aliases generated from `segments_data.json` (collision-checked against existing commands); `z_restore`/`zr` now re-scans media after restore instead of leaving files invisible to the Gallery |
| v3.1 | 2026-06 | batch-backup | partial | Samsung `values` field parsing fix for checkbox dialog *(carried over, not reviewed this session)* |
| v3.0 | 2026-06 | batch-backup | partial | Merge/append/skip logic -- merge tested working *(carried over, not reviewed this session)* |
| v3.0 | 2026-06 | batch-backup | partial | Full inline documentation + Android 16 find fix *(carried over, not reviewed this session)* |
| v2.1 | 2026-06 | backup-all | deployed | sync_history.csv logging on every run *(carried over, not reviewed this session)* |
| v2.0 | 2026-07 | segment_manager | corrected | Clipboard simplified to hashtags-only -- removed per-platform hashtag generation and the `<segment><counter>` title line |
| v2.0 | 2026-05 | segment_manager | tested | *(superseded above)* Combined clipboard: title+hashtags, --quick mode, platform modes |
| v2.0 | 2026-07 | org-camera-album | doc-corrected | This README previously described a segment-aware radio-dialog router; the real script is a simple free-text-name mover with no segment awareness. Doc corrected to match; segment-aware behavior lives in `mkshot`/`mkshot_burn` instead |
| v2.0 | 2026-05 | org-camera-album | tested | *(doc corrected above)* Smart auto-router: hot segments first, one-tap routing |
| v2.0 | 2026-05 | batch-backup | partial | All-folders dialog, Samsung cancel detection, HOME/PATH guard *(carried over, not reviewed this session)* |
| v1.0 | 2026-04 | content-pipeline | tested | Initial 5-step pipeline, --hot working across ZFlip7 |

## Known issues (carried over, unverified)

- `batch-backup` interactive checkbox: dialog shows and folders listed correctly.
  Confirm button triggers cancel. Fix deployed (v3.1 `parse values text field`).
  **Needs test confirmation on ZFlip7.**
- `transfer-export` wireless path: untested. Blocked on Pi physical access
  (micro HDMI cable ordered).
- `org-collect` multi-source gatherer: not yet built. Blocked on confirming
  Instagram Edits and Quick Share paths on device.
- **v5 burn integration** (this doc's new proposal): not built. Needs
  `content-pipeline`'s actual source before it can be wired in for real.
