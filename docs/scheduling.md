# Scheduling: keeping the project synced on its own

`backup-all` (phone → GitHub) and `sync-in` (GitHub → phone) are the two
halves of sync. Run by hand they work fine; run on a schedule, the project
stays consistent across both phones without anyone remembering to tap a
widget. This page covers what runs, on what schedule, and why
`termux-job-scheduler` won the tradeoff.

## What runs: nightly-sync

`.shortcuts/nightly-sync` does the whole round trip, in this order:

1. **`sync-in`** — pull GitHub, deploy `.shortcuts/` and `.bashrc` to their
   live locations. This is the step that would have auto-fixed the stale-
   `.bashrc` banner issue of 2026-10-12: the repo had the fix, the phone
   just never deployed it.
2. **`backup-all`** — snapshot the phone, fetch + rebase, push.

Order matters: pull-then-push is the safe convention, and `backup-all` v4
already fetches + rebases before pushing, so a scheduled run never
force-pushes over the other phone.

Failure handling: `backup-all` refuses to push on real conflicts instead of
guessing (`merge-counters` only auto-resolves `segments_data.json`). A
scheduled run that hits one logs the failure and fires a
`termux-notification` — it never dies quietly. Logs live in
`~/.shortcuts/.hidden/nightly-sync/` (newest 20 kept). Both steps are
invoked via `bash` explicitly, so a lost exec bit can never silently skip
the run (cf. the 2026-10-12 incident).

## The tradeoff: which scheduler?

| | termux-job-scheduler ✅ (chosen) | cronie | Tasker |
|---|---|---|---|
| Timing model | Inexact, constraint-based ("run when on WiFi + charging") | Exact cron expressions | Exact, very reliable |
| Survives Doze / reboot | Yes — OS-managed, persisted across reboots | Only with Termux:Boot + held wakelock + battery-optimization exemption; Doze can still delay runs | Yes — very sticky once configured |
| Needs | Termux:API app + `pkg install termux-api` | `pkg install cronie` + Termux:Boot app | Tasker (paid) + Termux:Tasker plugin |
| Best for | "Keep in sync" jobs where the exact minute doesn't matter | Exact-minute schedules; cron veterans | Complex conditions ("if home WiFi and after midnight"), exact timing with no babysitting |
| Watch out | No exact timing; 15-minute minimum interval; the OS may defer runs (harmless for sync) | Fragile on stock Android; OEM task killers; needs babysitting across OS updates | Paid app; more moving parts; overkill for a daily sync |

Why job-scheduler won here: a sync job wants *eventual consistency*, not
"02:00 sharp". The constraints (unmetered network + charging) map directly
onto "don't burn mobile data or battery", and there is zero babysitting
compared with keeping `cronie` alive under Doze. If exact timing ever
matters (e.g. a pre-shoot backup), Tasker is the upgrade path; the
`nightly-sync` script itself doesn't change.

## Setup

One-time, on the phone (Termux:API app installed, `termux-api` package
installed):

```bash
schedule-sync
```

This registers job 1001 → `~/.shortcuts/nightly-sync`: at most once every
24h, only on unmetered network while charging, persisted across reboots.
Re-running `schedule-sync` replaces the registration (same job id), so it
is idempotent — safe to re-run after editing the schedule.

Verify the available flags on-device any time with:

```bash
termux-job-scheduler --help
```

## Checking it ran

- **Logs:** `~/.shortcuts/.hidden/nightly-sync/` — newest first. A healthy
  run ends with `backup-all OK` and `=== done`.
- **Failures:** a `termux-notification` titled "nightly-sync" names the step
  that failed and the log file. Open Termux and run that step by hand
  (`bash ~/.shortcuts/sync-in` or `bash ~/.shortcuts/backup-all`) to see
  the full error.
- **First run:** after `schedule-sync`, the OS decides when the constraints
  are first met (unmetered network + charging) — it will not fire instantly
  on battery/mobile data. Plug in on WiFi and check the log directory.

## Notes

- The 24h period is a *maximum frequency*, not an appointment: the job runs
  at most once per 24h, whenever the constraints are satisfied.
- `git push` from the scheduled run uses whatever credential the phone
  already has configured — set that up once (it already works for manual
  `backup-all` runs) and the scheduled run inherits it.
- Two phones each running this stay consistent through GitHub as the hub:
  phone A pushes, phone B's next `sync-in` pulls. The per-device sync logs
  and `merge-counters` max-wins behavior are what make this safe.
