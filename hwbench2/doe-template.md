# DOE template

Copy this file per experiment: `docs/experiments/<name>-doe.md`.
Worked example: `hwbench2-doe-and-week-plan.md`.

A DOE doc answers six questions. Write it **before** running anything.

## 1. Question
One sentence. What decision will this data change?
> e.g. "Should the pipeline prefer MediaCodec HW encode over software encode?"

## 2. Hypotheses
Numbered, falsifiable, written before the first run. 2–4 max.
> H1 … / H2 … / H3 …

## 3. Factors & levels
| Factor | Levels | Notes / how verified |
|---|---|---|
| … | … | … |

State what you are *deliberately not* varying, and why.

## 4. Design
- Full factorial size: `<a> × <b> × <c> = N cells × R runs = T total` → keep or cut?
- Chosen design: pilot (screening) → main → stretch. Give the run math for each.
- Replication: how many trials per cell, and what statistic they feed (mean/stdev…).
- Randomization: what order is shuffled, how the order is logged.
- Blocking: what constitutes a block (device, day, session…).

## 5. Responses
Per-run columns: what you record, units, and how each is captured
(script flag, sysfs path, API call…).

## 6. Nuisance variables & controls
| Threat | Control | Verified how |
|---|---|---|
| … | … | … |

Include: environment, device state, input identity (checksums!), cooldown/reset
procedure, and anything the last experiment taught you.

## 7. Procedure
Numbered runbook. Each step has an exit criterion ("proceed only if…").

## 8. Analysis plan (pre-registered)
Which charts, which tables, which comparisons — decided now, not after
seeing the data. Name the files the analysis will produce.

## 9. Risks & graceful degradation
What breaks the week, and what the experiment degrades to if it does
("even 2 devices × pilot data is a publishable part 1").

## 10. Deliverables checklist
- [ ] raw data archived, unedited
- [ ] charts + summary
- [ ] write-up (repo docs)
- [ ] social cut-down
- [ ] resume bullet updated

---
*Discipline notes: hypotheses before runs. Pre-register the analysis.
Note what's confounded by everything you cut. n=1 unit per device is a
case study — say so; it reads as rigor, not weakness.*
