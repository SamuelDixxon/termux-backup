# Architecture

## System diagram

```mermaid
flowchart LR
    subgraph devices [3 Android Devices]
        D1[ZFlip7]
        D2[S23+]
        D3[Pixel 9a]
    end

    subgraph pipeline [content-pipeline 5 steps]
        P1[1 manager]
        P2[2 batch-backup]
        P3[3 backup-all]
        P4[4 segment_manager]
        P5[5 transfer-export]
    end

    subgraph storage [Storage]
        G[GitHub
termux-backup repo]
        E[Export
zips]
        R[Raspberry Pi
or SD card]
    end

    devices --> pipeline
    P1 --> P2 --> P3 --> P4 --> P5
    P3 -->|rsync + git| G
    P2 -->|zip| E
    P5 -->|SSH or USB| R
    G -->|sync-in| devices
```

## Data Flow

Which component reads and writes which storage location -- the dependency
graph underneath the step sequence above.

```mermaid
flowchart LR
    OCA[org-camera-album] -.reads.-> DCIM[DCIM/Camera
raw shoot files]
    OCA -.writes.-> SEG[storage/shared/
segment folders]
    OCA -->|moves files| BB[batch-backup]

    BB -.reads.-> SEG
    BB -->|zips to Export/| BA[backup-all]
    BB -.writes.-> ZIP[storage/shared/Export/
zip archives]

    BA -->|rsync + git push| MGR[segment_manager]
    BA -.reads.-> SC[.shortcuts/
local scripts]
    BA -.writes.-> GH[GitHub
termux-backup repo]

    MGR -.reads/writes.-> SEG
    MGR -->|hashtags to clipboard| TE[transfer-export]

    TE -.reads.-> ZIP
    TE -.writes.-> PI[SD card / Raspberry Pi
long-term archive]

    BURN[mkshot_burn /
org-camera-album-burn] -.reads.-> DCIM
    BURN -.reads/writes.-> SD[segments_data.json
counter, per segment]
    BURN -.writes.-> SEG

    HWB[hwbench] -.reads.-> SEG
    HWB -.writes.-> ZIP
```

`segments_data.json` is the one piece of shared state almost everything
touches -- `segment_manager`, the burn tooling, and `seg_add`/`seg_set_counter`/
`seg_bump` in `.bashrc` all read and write the same file, matched by `name`
in its `segments` list (not a dict keyed by segment, which an earlier draft
of the burn tooling guessed wrong on).
