# Operations

Install, dependencies, storage zones, Pi setup, and the utility reference.

## Storage Zones

| Zone | Path | Access | Notes |
|------|------|--------|-------|
| Termux home | `~/` | Full POSIX | Scripts, config, git repos |
| Shared storage | `~/storage/shared/` | FUSE-mounted | Camera roll, segments, Export |
| DCIM | `~/storage/shared/DCIM/Camera/` | FUSE + MediaStore | Raw shoot files |
| Export | `~/storage/shared/Export/` | FUSE | Canonical zip output |

**FUSE gotcha:** `zip *` silently fails inside DCIM. Always use absolute
paths and `zip -r .` from inside the source folder.

**Samsung Android 16 gotcha:** `find -not -path` returns empty results.
Use bash `[[ "$f" == .* ]]` inside the loop instead.

**MediaStore trash gotcha (new this pass):** files pending write or marked
trashed by Android show up as hidden dotfiles (`.20260410_233635.mp4`) and
are usually corrupt/incomplete (`moov atom not found` from ffmpeg). Every
`find` in the burn/tapestry tooling now excludes them with `! -name '.*'`.
Run `empty-gallery-trash` periodically to clear them out for good.

---

## Utility Functions (.bashrc)

| Function | Alias | Purpose |
|----------|-------|---------|
| `z_backup folder` | `zb` | Zip named folder to Export/ |
| `z_restore folder` | `zr` | Restore newest zip back to shared/ (now re-scans media after restore -- previously left restored files invisible to the Gallery until the next automatic scan) |
| `clean_termux` | `clean-termux` | Clean 5 junk zones (apt cache, trash, pip, tmp) |
| `empty_gallery_trash` | `empty-gallery-trash` | Remove Android MediaStore trash bypass 30-day hold |
| `seg_status` | `segstat` | Table: all segments with counter, folder exists, zipped |
| `export_summary` | `exsum` | List all zips in Export/ with sizes and dates |
| `seg_add name desc tags` | `segadd` | Add segment without opening REPL |
| `seg_set_counter name N` | `segset` | Set a segment counter directly (mass-upload sync) |
| `seg_bump name [N]` | `segbump` | Increment a segment counter by N (default 1) |
| `mkshot name` | `mks` | Create segment folder + optionally move DCIM files (not burn-aware) |
| `mkshot_burn name` | `mksb` | Same as `mkshot`, plus burns sequential labels and updates the counter |
| `pkg_check` | `pkgcheck` | Verify all required packages installed |
| `termux_info` | `tinfo` | One-screen: battery, WiFi, storage, segment count |
| `lsclip path` | `lsc` | List folder tree + copy to clipboard for sharing |
| `debug_folder name` | `dbf` | Full audit: permissions, file types, zip status, segment match |
| `gc_empty` | `gcempty` | Remove empty dirs from shared/ (GUI-deleted folders) |
| `extract_audio file` | `extractaudio` | Pull audio track out of a video |
| `probe_media file` | `probe` | Print codec/resolution/duration/bitrate |
| `compress_vid file` | `compvid` | Re-encode for smaller upload size |
| `waveform_img file` | `waveform` | Generate a waveform PNG from audio |

**Sourced, not duplicated:** `burn_thumb`, `burn_thumb_segment`, and
`_burn_thumb_core` are no longer defined in `.bashrc` -- it sources
`~/.shortcuts/burn_thumb.sh` instead, which is the single canonical copy.
`tapestry` and `sandwich` follow the same pattern: `.bashrc` just aliases
to `~/.shortcuts/tapestry` and `~/.shortcuts/sandwich`.

**Per-segment `cd` aliases (dynamic):** at shell start, `.bashrc` reads
`segments_data.json` and generates a plain alias for every segment name --
type `pistol` and you're in `~/storage/shared/pistol`. Generated fresh
every session, not hardcoded, so it stays in sync as segments are added or
renamed. Collision-safe: any segment name that's already a real command,
function, or alias (the `code` segment, for instance, would otherwise
silently shadow an actual `code` CLI) gets skipped and reported at shell
start instead of overwritten.

### Pipeline shortcuts

```bash
pipeline    # full 5-step content-pipeline
bb          # batch-backup interactive
bbhot       # batch-backup --hot
bball       # batch-backup --all
bbunzipped  # batch-backup --unzipped
mgr         # segment_manager.py
quick       # segment_manager.py --quick
syncup      # backup-all
transfer    # transfer-export
tapestry    # bash ~/.shortcuts/tapestry (grid)
sandwich    # bash ~/.shortcuts/sandwich (concat)
hwbench     # bash ~/.shortcuts/hwbench (cross-device benchmark)
segstat     # segment status table
exsum       # export summary
```

---

## Installation

```bash
pkg update && pkg install git rsync python jq zip termux-api ffmpeg coreutils
termux-setup-storage
git clone https://github.com/SamuelDixxon/termux-backup ~/termux-backup
cp ~/termux-backup/.shortcuts/* ~/.shortcuts/
cp ~/termux-backup/.bashrc ~/.bashrc
source ~/.bashrc
chmod +x ~/.shortcuts/*
```

`coreutils` added to the base install: the burn/tapestry timeout
protection depends on the `timeout` binary, which isn't guaranteed present
on a minimal Termux install.

---

## Dependencies

| Package | Install | Used by |
|---------|---------|---------|
| `zip` | `pkg install zip` | z_backup, batch-backup |
| `python3` | `pkg install python` | segment_manager, batch-backup, seg_add/seg_set/seg_bump |
| `jq` | `pkg install jq` | batch-backup, backup-folder, org-camera-album-burn.sh |
| `rsync` | `pkg install rsync` | backup-all, transfer-export |
| `git` | `pkg install git` | backup-all, sync-in |
| `termux-api` | `pkg install termux-api` | dialogs, clipboard, media-scan |
| `openssh` | `pkg install openssh` | transfer-export Pi SSH |
| `ncftp` | `pkg install ncftp` | transfer-export FTP fallback |
| `ffmpeg` | `pkg install ffmpeg` | burn_thumb.sh, tapestry -- **live now**, not just planned |
| `coreutils` | `pkg install coreutils` | `timeout` binary, used for hang protection in burn_thumb.sh + tapestry |
| a real `.ttf` font | `pkg install dejavu-fonts-ttf` | burn_thumb.sh's drawtext label -- fails loud now if none found |

---

## Raspberry Pi Setup

```bash
# On Pi:
sudo apt install rsync openssh-server -y
sudo systemctl enable ssh && sudo systemctl start ssh
# Set static IP in /etc/dhcpcd.conf:
#   static ip_address=192.168.1.100/24

# From Termux:
ssh-keygen -t ed25519
ssh-copy-id pi@192.168.1.100

# Update transfer-export config:
PI_USER="pi"
PI_IP="192.168.1.100"
PI_DEST="/home/pi/sd-archive"
```
