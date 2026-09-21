# Pipeline Stages

Each stage below is independently runnable -- see
[Stage Aliases](testing.md) for isolated invocation
and a non-destructive regression sweep. The choice of *which* script runs
a stage lives at the stage level, not buried in a single monolithic
flowchart -- each stage gets its own small diagram instead of one
giant combined one.

```mermaid
flowchart LR
    ST1[Stage 1
Capture Routing]
    ST15[Stage 1.5
Content Composition
optional, parallel]
    ST2[Stage 2
Archival]
    ST3[Stage 3
Sync]
    ST4[Stage 4
Metadata]
    ST5[Stage 5
Transfer]

    ST1 --> ST2 --> ST3 --> ST4 --> ST5
    ST1 -.optional, any time.-> ST15
```

Full end-to-end run: `bash ~/.shortcuts/content-pipeline`.

---

## Stage 1 -- Capture Routing

Two options, chosen per-run: plain (works for any folder, no counter) or
burn (requires the segment to already exist, since it needs a live
counter to label against). This was the "Pipeline v5" proposal in earlier
versions of this doc -- folded in directly now since the design settled
and the underlying scripts (`mkshot_burn`, `org-camera-album-burn.sh`)
have been through several real rounds of bug fixes.

```mermaid
flowchart TD
    START1([Stage 1: Capture Routing]) --> CHOICE1{Which script?}
    CHOICE1 -->|1A: plain| PLAIN1[org-camera-album
free-text folder name
move only, no counter]
    CHOICE1 -->|1B: burn| CHECK1{segment exists in
segments_data.json?}
    CHECK1 -->|yes| BURN1[org-camera-album-burn /
mkshot-burn segment
move + burn + counter update]
    CHECK1 -->|no| FALLBACK1[fall back to plain,
or seg-add first]
    PLAIN1 --> DONE1([-> Stage 2])
    BURN1 --> DONE1
    FALLBACK1 --> DONE1
```

**Open question for actual `content-pipeline` integration:** does Stage 1
currently know the segment name ahead of time, or is it picked
interactively mid-step (as `org-camera-album`'s free-text dialog does
today)? That determines whether the 1A/1B choice happens before or after
name entry. Share that script and this becomes a real diff instead of a
design doc.

---

## Stage 1.5 -- Content Composition (optional, parallel)

Not part of the backup chain -- a different purpose entirely (content
production, not archival), so it doesn't gate Stages 2-5. Runs any time
after Stage 1 has populated a folder.

```mermaid
flowchart TD
    START15([Stage 1.5: Content Composition
optional, any time after Stage 1]) --> WHICH15{tapestry or sandwich?}
    WHICH15 -->|grid, short-form| TAP15[tapestry
NxN simultaneous grid
crop-to-fill by default]
    WHICH15 -->|concat, long-form| SAND15[sandwich
sequential reel]
    TAP15 --> OUT15([Export/*.mp4 --
independent of backup stages])
    SAND15 --> OUT15
```

---

## Stage 2 -- Archival

```mermaid
flowchart TD
    START2([Stage 2: Archival]) --> MODE2{batch-backup mode}
    MODE2 -->|y, default| HOT2[--hot
auto-zip counter gte 50]
    MODE2 -->|c| CUSTOM2[interactive
checkbox dialog]
    MODE2 -->|n| SINGLE2[single folder
picker]
    HOT2 & CUSTOM2 & SINGLE2 --> DONE2([-> Stage 3])
```

---

## Stage 3 -- Sync

```mermaid
flowchart LR
    START3([Stage 3: Sync]) --> BA3[backup-all:
rsync + git push] --> DONE3([-> Stage 4])
```

---

## Stage 4 -- Metadata

```mermaid
flowchart LR
    START4([Stage 4: Metadata]) --> SM4[segment_manager:
hashtags to clipboard] --> DONE4([-> Stage 5])
```

Full internal detail (menu options, clipboard format) is in the
[segment_manager](components.md#segment_manager) deep dive -- this is just the
stage-level view.

---

## Stage 5 -- Transfer

```mermaid
flowchart LR
    START5([Stage 5: Transfer]) --> TE5[transfer-export:
SD card or Raspberry Pi] --> DONE5([pipeline complete])
```

---

## Future Proposal -- Session-First Reordering (v4)

Independent of the Stage 1 burn/plain choice above -- a different idea:
`segment_manager` moves to **step 1** so the selected segment name
flows via `session.json` into every downstream step. No duplicate prompts.

```mermaid
flowchart TD
    subgraph session [Shared Session State]
        SJ[session.json
segment + counter + mode]
    end

    subgraph sources [Media Sources - org-collect NEW]
        S1[DCIM/Camera]
        S2[Instagram Edits]
        S3[Quick Share BLE]
        S4[Downloads]
        S5[Screenshots]
    end

    subgraph modes [Folder Naming Mode]
        M1[incremental
pistol/ skip/]
        M2[episode
m111/ mcp99/]
        M3[dated
hike_20260615/]
    end

    P1([1 segment_manager
pick segment + mode]) -->|writes| SJ
    P2([2 org-collect NEW
gather all sources])
    P3([3 batch-backup
zip to Export])
    P4([4 backup-all
GitHub sync])
    P5([5 transfer-export
SD or Pi])

    SJ -->|reads| P2
    SJ -->|reads| P3

    S1 & S2 & S3 & S4 & S5 --> P2
    P2 -->|incremental| M1
    P2 -->|episode| M2
    P2 -->|dated| M3
    M1 & M2 & M3 --> P3
    P3 --> P4 --> P5
```

### session.json schema

```json
{
  "segment": "pistol",
  "counter": 181,
  "mode": "incremental",
  "timestamp": "2026-06-15T14:30:00"
}
```

| mode | folder | use case |
|------|--------|----------|
| `incremental` | `pistol/` | open-ended series, files accumulate |
| `episode` | `m111/` | numbered series, each shoot discrete |
| `dated` | `hike_20260615/` | one-off or travel content |
