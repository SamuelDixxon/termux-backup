# Testing

## Stage Aliases (regression testing)

New `.bashrc` aliases for running any single stage in isolation, without
going through the full `content-pipeline` script -- useful for testing one
stage after a change without re-running everything else.

```bash
# Stage 1
stage1        # org-camera-album (plain)
stage1b       # org-camera-album-burn.sh

# Stage 1.5
stage15grid   # tapestry
stage15reel   # sandwich

# Stage 2
stage2        # batch-backup (interactive)
stage2hot     # batch-backup --hot

# Stage 3
stage3        # backup-all

# Stage 4
stage4        # segment_manager.py
stage4quick   # segment_manager.py --quick

# Stage 5
stage5        # transfer-export
```

**`regress`** -- a non-destructive smoke test, not a full pipeline run. It
exercises Stage 1.5 (`tapestry` + `sandwich`) against a dedicated
`regtest` segment, auto-created in `segments_data.json` if missing, and
reports pass/fail per check. Deliberately scoped to Stage 1.5 only:
Stage 1's burn path consumes real `DCIM/Camera` contents, and Stages 2/3/5
touch real zip archives, your actual GitHub repo, and actual transfer
targets -- none of those are things an automated "just testing" command
should run unattended. Test those stages individually via their aliases
above, with intent, not via a sweep.

**Prerequisite:** `regress` needs a few sample clips already sitting in
`~/storage/shared/regtest/` once, since it can't fabricate real video
files -- it's testing the scripts, not generating fixtures.

## Philosophy

- Isolated stages beat end-to-end sweeps for iteration speed.
- Destructive paths (burn, push, transfer) are always opt-in, never swept.
- Every fixed bug gets its regression story kept in [debugging](debugging.md) --
  honest, not cleaned up after the fact.
