# hwbench2 — experiment plan (DOE)

## The question
Is ffmpeg's MediaCodec hardware acceleration actually faster *and*
reliable vs software encode, and how do three real SoCs (Exynos 2500,
Snapdragon 8 Gen 2, Tensor G4) differ under sustained load — thermally
and on battery?

## Hypotheses (written before the first run)
1. HW encode is faster than SW on all three SoCs, but the gap varies by vendor.
2. Sustained runs show throttling knees at different temperatures per SoC.
3. At least one path/device combo still exhibits the documented TIMEOUT/FAIL modes.

## Factors & levels
| Factor | Levels | Notes |
|---|---|---|
| Device (SoC) | Z Flip 7 (Exynos 2500), S23+ (SD 8G2), Pixel 9a (Tensor G4) | verify via `--prep` |
| Codec | h264, hevc | hevc only in `--full` |
| Path | sw, hw_enc (+hw_dec stretch) | hw = MediaCodec |
| Resolution | 1080p (+4K stretch) | inputs cached, sha-pinned |

## Design
- **Full factorial reference:** 3 × 2 × 3 × 2 = 36 cells × 15 runs =
  **540 runs — rejected** as too much for one experimenter.
- **Pilot (screening):** 1 device × h264 × {sw, hw_enc} × 1080p ×
  (3 trials + 5 sustained) = **16 runs, ~25 min.** Validates telemetry,
  CSV schema, cooldown logic.
- **Main:** 3 devices × 2 codecs × {sw, hw_enc} × 1080p ×
  (5 trials + 10 sustained) = **180 runs, ~60/device, 60–90 min/device**
  incl. cooldowns.
- **Stretch (if time):** +hw_dec path, +4K cells.
- **Replication:** 5 trials/cell → mean/stdev (existing hwbench convention).
- **Sustained block:** 10 back-to-back runs/cell, no cooldown inside the
  block — heat soak is the treatment.
- **Randomization:** cell order shuffled per run (`shuf`); order logged to
  `run_order_<ts>.txt`.
- **Blocking:** one device = one block; prep checklist identical per block.

## Responses (per run)
`result` (OK/FAIL/TIMEOUT), `elapsed_s`, `fps`, `temp_c_start/end`,
`cpu_mhz_avg`, `batt_start/end`, `out_bytes` — plus per-cell success rate,
mean/stdev.

## Controls (nuisance variables)
- Unplugged, battery > 60% (charging adds heat, ruins drain metric)
- Airplane mode ON, brightness fixed low, all apps closed, 5-min idle before start
- Internal storage only (documented FUSE variance on shared storage)
- Identical input bytes on all devices — generate once, copy `in_*.mp4`,
  verify sha (`hwbench_plot.py` warns if shas differ)
- Cooldown between cells to baseline + 2°C (script-enforced, 10-min cap)
- Same ambient conditions per session; record it in notes

## Run sequence
1. Copy `hwbench2.sh` + `hwbench_plot.py` to all 3 devices
   (`~/.shortcuts/`, `chmod +x`). Install matplotlib
   (`pkg install python matplotlib`).
2. Run `--prep` on each device. Proceed only if: all green, SoCs
   confirmed, input SHAs match across devices.
3. Pilot on device 1 (`--pilot`, ~25 min). Proceed only if: CSV has
   temp/batt/fps columns populated, no script crashes.
4. Fix pilot issues; if clean, pilot device 2. First look at plots —
   proceed only if pilot CSVs plot without errors.
5. Full runs (`--full`): device 1 + device 2, then device 3. Rerun failed
   cells. Done when: 3 CSVs, all cells have n=5 trials.
6. Analysis: `hwbench_plot.py *.csv` → 4 charts + summary. Sanity-check
   numbers against the hypotheses above.
7. Write-up (repo results section) + first social post (chart drop).

## Risks
- A device throttles so hard the 10-run block takes forever → `timeout`
  caps each run; cooldown cap keeps the session bounded.
- Battery API granularity too coarse → report method limits honestly.
- Life happens mid-run → the design degrades gracefully: even 2 devices ×
  pilot data is a publishable "part 1".

## Deliverables checklist
- [ ] 3 per-device CSVs in `Export/`
- [ ] 4 charts + `summary.txt`
- [ ] README "hwbench2 results" section
- [ ] 1 social post (chart drop)
- [ ] Resume bullet updated with the 3-SoC numbers
