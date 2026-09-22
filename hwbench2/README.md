# hwbench2 — 3-SoC hardware encode benchmark

DOE-driven sequel to `hwbench`: is ffmpeg's MediaCodec hardware
acceleration actually faster *and* reliable vs software encode, and how
do three real SoCs differ under sustained load — thermally and on battery?

**Status (2026-09-22):** scripts drafted and syntax-checked; not yet run
on-device. Device/SoC mappings are drafts until `--prep` verifies them.
One handset per SoC — this is a case study, not a population comparison.

## Files

- `hwbench2.sh` — the benchmark: trial + sustained heat-soak blocks,
  thermal/battery telemetry, CSV output, script-enforced cooldowns.
- `hwbench_plot.py` — charts + summary tables from the CSVs
  (`pkg install python matplotlib`; prints a text summary without it).
- `DOE.md` — the experiment plan: hypotheses, factors, run math,
  controls, risks. Written before the first run.
- `doe-template.md` — reusable skeleton for future experiments.

## Usage

```bash
cp hwbench2.sh ~/.shortcuts/hwbench2
cp hwbench_plot.py ~/.shortcuts/
chmod +x ~/.shortcuts/hwbench2 ~/.shortcuts/hwbench_plot.py

hwbench2 <segment> --prep    # device checks + input caching (no benchmark)
hwbench2 <segment> --plan    # print the experiment plan and exit
hwbench2 <segment> --pilot   # screening: h264, 1080p, 16 runs (~25 min)
hwbench2 <segment> --full    # the DOE: h264+hevc, 1080p, 180 runs total
```

Cross-device rule: generate inputs once (`--prep` on device 1), copy
`~/.cache/hwbench2/in_*.mp4` to the other devices, verify SHA matches.
`hwbench_plot.py` warns if input SHAs differ.

Results land in `~/storage/shared/Export/hwbench2_<device>_<timestamp>.csv`.

## Design (summary)

3 handsets × H.264/HEVC × software/hardware encode × 1080p,
5 trials + 10 sustained runs per cell = **180 runs**. Pilot first
(1 device, 16 runs) to validate telemetry and CSV schema before the
full matrix. Full detail: [DOE.md](DOE.md).

The original single-device harness is documented at
[../docs/hwbench.md](../docs/hwbench.md).
