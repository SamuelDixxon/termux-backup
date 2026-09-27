# hwbench2 — week 2 run plan (Sun 9/27 → Sat 10/3)

Second attempt at the run week (see `hwbench2-doe-and-week-plan.md` for the
original 9/21–9/27 plan). Same DOE, same exit criteria — this is the
execution schedule. Evening slots only: during a run the phone must be
unplugged, in airplane mode, brightness low, apps closed, 5 min idle.

## Timeline

| Day | Task | Exit criteria |
|---|---|---|
| **Sun 9/27** | Setup: copy `hwbench2.sh` + `hwbench_plot.py` to all 3 phones (`~/.shortcuts/`, `chmod +x`). `pkg install python matplotlib` on each. (Arduino USB backup work has priority tonight — DOE setup is the 15-min filler.) | Scripts present + executable on all 3; matplotlib installed |
| **Mon 9/28** | Segment + prep night. Pick source clip (real motion, ≥10s, 1080p+), place in `~/storage/shared/<segment>/`, run `--prep` on Z Flip 7, record SHAs. Copy `~/.cache/hwbench2/in_*.mp4` to the other two phones *before* their `--prep`; verify SHAs match on all 3. | 3 green `--prep`s; identical input SHAs across devices |
| **Tue 9/29** | Pilot on device 1: `hwbench2 <segment> --pilot` (~25 min, evening). Plot the pilot CSV immediately with `hwbench_plot.py`. | CSV has temp/batt/fps columns populated; no script crashes; 4 charts generate without errors |
| **Wed 9/30** | Buffer night. Pilot clean → pilot device 2. Anything weird → fix script, re-pilot device 1. | Either device-2 pilot CSV in hand, or root-caused pilot issue with fix |
| **Thu 10/1** | Full run, device 1: `hwbench2 <segment> --full` (60–90 min incl. cooldowns). | 1 CSV in `Export/`, all cells have n=5 trials |
| **Fri 10/2** | Full run, device 2 (evening). Device 3 too if a second window exists, else slides to Sat. | 2–3 CSVs in `Export/` |
| **Sat 10/3** | Analysis: `hwbench_plot.py *.csv` → 4 charts + `summary.txt`. Sanity-check vs the 3 hypotheses. README "hwbench2 results" section, chart-drop social post, resume bullet update. | Published post; repo updated; resume bullet updated |

## Preconditions (every run night)

- Unplugged, battery > 60%, airplane mode ON, brightness fixed low, all apps closed, 5-min idle
- Same ambient conditions per session; record in notes
- Internal storage only

## Risks & graceful degradation

- A device throttles so hard the 10-run block takes forever → `timeout` caps each run; cooldown cap keeps the night bounded.
- Battery API granularity too coarse → report method limits honestly.
- Life happens mid-week → the design degrades gracefully: even 2 devices × pilot data is a publishable "part 1".
- Input SHA mismatch across devices → stop, re-copy inputs from device 1, re-verify before any full run. The plotter's comparability guard is the backstop, not the plan.

## Deliverables checklist

- [ ] 3 per-device CSVs in `Export/`
- [ ] 4 charts + `summary.txt`
- [ ] README "hwbench2 results" section
- [ ] 1 social post (chart drop)
- [ ] Resume bullet updated with the 3-SoC numbers
