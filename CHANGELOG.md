# Changelog

## 2026-09-29 — burn label standardization (`burn_thumb.sh`)

### Changed
- **Label font size is now relative to frame height** (`_burn_thumb_core`).
  Previously `fontsize=120` was a fixed pixel value applied at each clip's
  native resolution, so the burned label visibly changed size whenever a
  clip's resolution differed — 120px is ~1/6 of a 720p frame but ~1/18 of a
  4K frame. This showed up on a climb clip that had been re-exported from an
  editor (blur added) at a different timeline resolution than the camera
  originals. The script now probes the frame height with `ffprobe` and sets
  `fontsize = height / 12`, so the label is always the same fraction of the
  picture on 720p, 1080p, 4K, and anything else. Applies automatically to
  `burn_thumb`, `burn_thumb_segment`, and `mkshot_burn` (all share
  `_burn_thumb_core`).
- **Outline (`borderw`) scales the same way** (`height / 200`), since it was
  also an absolute pixel value with the same problem. Floors of 24px /
  2px keep tiny clips legible.
- **Default burn duration shortened: 3s → 0.25s** (`burn_thumb` and
  `burn_thumb_segment`). The label only needs to cover frame 0 — that's the
  frame thumbnailers use — so a quarter-second flash keeps the thumbnail
  labeled without the text lingering over the video. Override any time with
  `--dur N`.
- If the height probe ever fails, the script prints a notice and falls back
  to the old fixed values (120 / 6) rather than failing the burn.

### Notes
- Shortening the burn window does **not** reduce ffmpeg encode time: the
  whole file is still re-encoded (`libx264`) either way; `enable=` only
  controls which frames get the text drawn. A real speedup would need a
  head-only re-encode (first ~1s) concatenated with a stream copy of the
  remainder — possible follow-up if batch burn times become a bottleneck.
- Height-relative sizing is aspect-ratio agnostic: it standardizes the
  label across resolutions even though phone footage stays ~16:9.
