# Changelog

| Version | Date | Component | Status | Summary |
|---------|------|-----------|--------|---------|
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
