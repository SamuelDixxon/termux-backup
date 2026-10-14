# termux-backup · Content Pipeline

![Shell](https://img.shields.io/badge/shell-bash-89e051?style=flat-square)
![Python](https://img.shields.io/badge/python-3.x-3572A5?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Android%20%2F%20Termux-brightgreen?style=flat-square)
![Devices](https://img.shields.io/badge/devices-S23%2B%20%7C%20Pixel%209a%20%7C%20ZFlip7-blue?style=flat-square)

A session-driven, multi-source content pipeline running entirely on Android via Termux.
No laptop. No cloud subscription. 25 min manual post-shoot workflow reduced to under 4 min automated.

> Built by **Samuel Dixon** -- Product Test Engineer, Austin TX
> linktr.ee/sdixoninvesting -- @sdixoninvesting

---

## Why This Project

This started as a personal content pipeline and became a running exercise in
the same discipline I used in semiconductor product/test engineering,
applied to consumer Android hardware instead of a DUT:

- **System design** -- a 5-stage pipeline (capture routing -> zip archival ->
  cross-device sync -> metadata tagging -> long-term storage) with a shared
  JSON schema (`segments_data.json`) as the single source of truth every
  stage reads and writes.
- **Automation, not scripts** -- Bash/Python tooling that moves files,
  drives `ffmpeg` for thumbnail labeling and video composition, manages
  clipboard/metadata state, and talks to Android's dialog/media APIs
  through Termux, with no laptop or cloud service involved.
- **Debugging methodology** -- most of the real engineering here happened
  in a string of `set -x` trace-driven debugging sessions that found and
  fixed actual production bugs: a classic bash argument-parsing footgun
  (`for arg in "$@"` desyncing from `shift`), a silent-failure anti-pattern
  that made every ffmpeg error look identical to success, a process hang
  caused by ffmpeg's own interactive stdin listener, and race conditions
  specific to Android's FUSE-mounted shared storage. See
  [docs/debugging.md](docs/debugging.md) for the full list, kept honest
  rather than cleaned up after the fact.
- **Cross-device empirical testing** -- `hwbench` runs an identical test
  matrix (software vs. MediaCodec hardware encode/decode, N repeated
  trials, mean/stdev) on a Samsung Exynos device and a Google Tensor
  device, producing comparable CSVs instead of trusting vendor claims or
  forum reports.
- **Process improvement, measured** -- the original manual post-shoot
  workflow (25 minutes) is now under 4 minutes automated, and every
  refactor in this repo's history exists because duplicating logic across
  files caused real bugs to go half-fixed -- consolidated to single
  sources of truth once that became clear.

---

## Active Work

What I'm building and measuring right now, in the open:

- **hwbench2 -- a hardware encode benchmark run like a real experiment.**
  The original `hwbench` showed MediaCodec results were worth questioning;
  the sequel is a formal DOE: 3 handsets × H.264/HEVC × software/hardware
  encode, 5 trials + 10 sustained thermal runs per cell (180 runs), with
  controls for battery state, thermals, and background activity.
  Scripts and experiment plan live in [hwbench2/](hwbench2/) — drafted,
  on-device validation is next.
  ([docs/hwbench.md](docs/hwbench.md) covers the original harness.)
- **Deliberate practice, published.** Weekly build blocks turn phone time
  into terminal-emulator craft: one experiment, one write-up, one
  résumé-ready artifact at a time. This README refactor was the first.

---

## Cross-device sync

Three phones share one repo, so sync is designed to make conflicts
structurally impossible rather than resolved after the fact:

- **Rebase before push** — phones fast-forward onto `origin/main`; history
  stays linear, no merge commits.
- **One sync log per device** (`sync_history_<device>.csv`) — git detects
  conflicts at file granularity, so one file per writer means two phones
  can never write the same bytes. (The old shared `sync_history.csv` was
  split per-device on 2026-10-04; full history via
  `cat sync_history_*.csv`.)
- **Max-wins counter merges** — `segments_data.json` conflicts auto-resolve
  with the higher episode counter winning; anything else refuses and asks
  a human.

## Tools

Everything lives in `.shortcuts/` (Termux:Widget-ready) and self-describes
via `# SUMMARY:` / `# GROUP:` header lines. On-device, `tools` renders this
inventory grouped; on login the shell prints a one-line banner and only
mentions what's new since your last session.

**Pipeline** — `content-pipeline-segment-first` (session-first: pick segment, copy hashtags, manage counter) · `pipeline` (post-shoot chain: organize → zip → hashtags) · `manager` (hashtag CRUD)

**Media** — `org-camera-album` (move DCIM/Camera into a new folder) · `org-media` (organize Camera/Screenshots/Downloads/Edits with filters + dry-run; no-arg = original behavior) · `org-camera-album-burn.sh` (organize into a segment + burn sequential thumbnails) · `burn_thumb.sh` (burn text labels onto video) · `tapestry` (NxN clip grid) · `sandwich` (stitch clips into one reel) · `video-utils.sh` (shared ffmpeg helpers)

**Backup & sync** — `backup-all` (mirror to git repo: rebase-before-push, counter-safe) · `sync-in` (pull repo, mirror scripts, update .bashrc) · `merge-counters` (auto-resolve counter conflicts, max wins) · `backup-folder` (dialog-driven zip to Export/) · `batch-backup` (zip segment folders, 4 modes) · `transfer-export` (Export/ → SD card or Raspberry Pi)

**Content** — `pistol_squat_log.sh` (log a session, copy summary) · `week-recap` (title + description for a week's bundle)

**Utility** — `tools` (this inventory, live) · `clean-session` (fresh Termux start)

## Docs

| Doc | Answers |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How does data move? (system diagram + data flow) |
| [docs/pipeline.md](docs/pipeline.md) | What are the 5 stages, and what's the session-first v4 proposal? |
| [docs/components.md](docs/components.md) | How does each component work? (deep dives) |
| [docs/hwbench.md](docs/hwbench.md) | Is MediaCodec actually reliable? (benchmark harness) |
| [hwbench2/README.md](hwbench2/README.md) | What's the 3-SoC encode experiment? (design + scripts) |
| [docs/testing.md](docs/testing.md) | How is this tested? (stage aliases, `regress`) |
| [docs/debugging.md](docs/debugging.md) | What broke, and what did it teach? |
| [docs/proposals.md](docs/proposals.md) | What's next? (voice control, efficiency ideas) |
| [docs/operations.md](docs/operations.md) | Install, dependencies, storage zones, Pi setup, utility reference |
| [docs/scheduling.md](docs/scheduling.md) | How does the project stay synced on its own? (nightly-sync, scheduler tradeoffs) |
| [docs/changelog.md](docs/changelog.md) | What changed, when -- and what's still unverified |

---

## Quick install

```bash
pkg update && pkg install git rsync python jq zip termux-api ffmpeg coreutils
termux-setup-storage
git clone https://github.com/SamuelDixxon/termux-backup ~/termux-backup
cp ~/termux-backup/.shortcuts/* ~/.shortcuts/
cp ~/termux-backup/.bashrc ~/.bashrc
source ~/.bashrc
chmod +x ~/.shortcuts/*
```

Full install notes, dependencies, and Raspberry Pi setup:
[docs/operations.md](docs/operations.md).

---

## Author

**Samuel Dixon** -- Product Test Engineer -- Austin TX
[linktr.ee/sdixoninvesting](https://linktr.ee/sdixoninvesting)

*Outdoors -- Tech -- Fitness -- Education*
