# termux-backup · System Diagrams

Diagrams for the two most complex components (`batch-backup`, `manager`)
and the full pipeline. Render with any Markdown viewer that supports Mermaid
(GitHub, Obsidian, VS Code + Mermaid plugin).

---

## 1. Full content-pipeline flow

```mermaid
flowchart LR
    A([org-camera-album]) -->|moves files| B([batch-backup])
    B -->|zips to Export/| C([backup-all])
    C -->|rsync + git push| D([manager])
    D -->|hashtags to clipboard| E([transfer-export])

    subgraph storage [Android Storage Zones]
        direction TB
        S1[DCIM/Camera\nraw shoot files]
        S2[storage/shared/\nsegment folders]
        S3[storage/shared/Export/\nzip archives]
        S4[GitHub\ntermux-backup repo]
        S5[SD card / Raspberry Pi\nlong-term archive]
    end

    A -.->|reads| S1
    A -.->|writes| S2
    B -.->|reads| S2
    B -.->|writes| S3
    C -.->|reads .shortcuts/| S4
    D -.->|reads/writes| S2
    E -.->|reads| S3
    E -.->|writes| S5
```

---

## 2. batch-backup component

### 2a. Decision tree — mode selection

```mermaid
flowchart TD
    START([batch-backup called]) --> PRE[preflight check\nzip / python3 / jq / termux-dialog]
    PRE -->|missing pkg| FAIL_PRE([exit 1\npkg install hint])
    PRE -->|all present| LOAD[parse segments_data.json\nbuild SEG_NAMES + SEG_COUNTERS arrays]
    LOAD --> MODE{mode arg?}

    MODE -->|--hot| HOT[filter segments\ncounter >= 50]
    MODE -->|--all| ALL[all segments with\na matching folder]
    MODE -->|--unzipped| UNZ[segments with folder\nbut no zip in Export/]
    MODE -->|interactive| DLG[termux-dialog checkbox\nshow all available folders]

    HOT --> RESOLVE
    ALL --> RESOLVE
    UNZ --> RESOLVE
    DLG -->|code -2 = cancel| CANCEL([exit 0])
    DLG -->|selections made| PARSE[parse index field\nfallback: parse text field\nSamsung OneUI compat]
    PARSE --> RESOLVE

    RESOLVE[resolve_folders per segment\nexact + digit-suffix + short-alias match]
    RESOLVE --> DEDUP[deduplicate + filter empty strings]
    DEDUP --> EMPTY{any targets?}
    EMPTY -->|no| PARITY[parity report only]
    PARITY --> EXIT0([exit 0])
    EMPTY -->|yes| LOOP

    subgraph LOOP [zip loop]
        direction TB
        L1[for each folder] --> L2[z_backup folder]
        L2 -->|success| L3[PASS++\nprint size]
        L2 -->|fail| L4[FAIL++\nadd to FAILED list]
        L3 --> L5{more folders?}
        L4 --> L5
        L5 -->|yes| L1
        L5 -->|no| SUMMARY
    end

    SUMMARY[print summary\nSucceeded / Failed counts] --> PARITY2[parity report\nshows unbacked segments]
    PARITY2 --> RESULT{FAIL == 0?}
    RESULT -->|yes| OK([exit 0])
    RESULT -->|no| ERR([exit 1\npipeline halts])
```

### 2b. resolve_folders matching strategy

```mermaid
flowchart TD
    IN([segment name e.g. mcp]) --> E1{shared/mcp\nexists?}
    E1 -->|yes| ADD1[add: mcp]
    E1 -->|no| E2

    E2[scan all dirs in shared/] --> E3{name + digits?\ne.g. mcp96, mcp98}
    E3 -->|match| ADD2[add: mcp96, mcp98]
    E3 -->|no match| E4

    E4{single letter\n+ digits?\ne.g. m81, m90-m99} --> E5{first char matches\nAND segment len <= 4?}
    E5 -->|yes| ADD3[add: m81, m90...m99]
    E5 -->|no| E6

    E6{DCIM/mcp\nexists?} -->|yes| ADD4[add: mcp via DCIM path]
    E6 -->|no| DONE2

    ADD1 --> DONE[sort -u\nreturn unique list]
    ADD2 --> DONE
    ADD3 --> DONE
    ADD4 --> DONE
    DONE2([no matches\nreturn empty])
```

### 2c. z_backup internals

```mermaid
flowchart TD
    IN2([z_backup folder-name]) --> BIN[locate zip binary\nfull Termux path first\nfallback: command -v zip]
    BIN -->|not found| FAIL2([exit 1\npkg install zip])
    BIN -->|found| RES[resolve src path\nshared/ first\nthen DCIM/]
    RES -->|not found| FAIL3([exit 1])
    RES -->|found| EMPTY2{ls -A src\nempty?}
    EMPTY2 -->|yes| SKIP([return 0\nSKIPPED warning])
    EMPTY2 -->|no| MKDIR[mkdir -p Export/]
    MKDIR --> ZIP[cd into src\nzip -9 -r zip_path .]
    ZIP -->|exit 0| SIZE[du -sh zip\nprint size + path]
    ZIP -->|exit != 0| CLEAN[rm partial zip\nreturn 1]
    SIZE --> OK2([return 0])
```

---

## 3. manager (segment_manager.py) component

### 3a. Top-level REPL loop

```mermaid
flowchart TD
    START2([python3 segment_manager.py]) --> LOAD2[load segments_data.json\ndefault data if missing/corrupt]
    LOAD2 --> PCHECK[parity check on startup\nwarn on unbacked segments]
    PCHECK --> MENU

    subgraph MENU [main menu loop]
        direction TB
        M0[print menu\nsorted by usage least to most] --> INPUT{user input}
        INPUT -->|1| SEARCH[Search and Copy]
        INPUT -->|2| ADD[Add new series]
        INPUT -->|3| EDIT[Edit series]
        INPUT -->|4| DELETE[Delete series]
        INPUT -->|5| LIST[List all + stats]
        INPUT -->|q| QUIT([exit 0])
        SEARCH --> SAVE[save_data\ncounter += 1]
        ADD --> SAVE
        EDIT --> SAVE
        DELETE --> SAVE
        SAVE --> M0
        LIST --> M0
    end
```

### 3b. Search and Copy flow (option 1 — most used path)

```mermaid
flowchart TD
    S1([user picks option 1]) --> S2[prompt: search term\nEnter = show all]
    S2 --> S3[filter segments by\nname or short_desc match]
    S3 --> S4{any results?}
    S4 -->|no| S5([print: no matches\nback to menu])
    S4 -->|yes| S6[display filtered list\nsorted by counter asc\nbadge NEW if 0 / HOT if >=50]
    S6 --> S7[user picks number]
    S7 -->|invalid| S8([back to menu])
    S7 -->|valid| S9[print full_desc\nprint hashtags]
    S9 --> S10[termux-clipboard-set hashtags]
    S10 --> S11[counter += 1\nsave_data]
    S11 --> S12([back to menu\ncounter drives --hot targeting\nin batch-backup])
```

### 3c. Data model

```mermaid
erDiagram
    SEGMENT {
        int id PK
        string name
        string short_desc
        string full_desc
        int counter
        list hashtags
    }
    SEGMENTS_DATA {
        list segments
    }
    SEGMENTS_DATA ||--o{ SEGMENT : contains
```

---

## 4. Component complexity summary

| Script | Lines | Mode | Complexity driver |
|--------|-------|------|-------------------|
| `batch-backup` | ~390 | bash | 4 run modes, folder resolution strategies, Samsung dialog compat, pipeline exit codes |
| `segment_manager.py` | ~200 | python REPL | stateful counter, CRUD, clipboard integration, parity check |
| `transfer-export` | ~200 | bash | dual transport (SSH/rsync + FTP fallback), USB mount detection, SD label routing |
| `content-pipeline` | ~180 | bash | orchestrates all 5 steps, exit code propagation, y/c/n branching at step 2 |
| `org-camera-album` | ~50 | bash | FUSE path resolution, termux-media-scan |
| `backup-all` | ~30 | bash | rsync mirror + git diff detection |
| `z_backup` (.bashrc) | ~45 | bash func | binary path resolution, recursive zip, empty folder guard |

---

## 5. Design decisions

**Why decomposable scripts over a monolith**
Each script exits with a meaningful code and can be run standalone or composed
into `content-pipeline`. This means you can test `z_backup pistol` directly
without running the full pipeline, and failures halt the pipeline at the exact
failing step with a clear message.

**Why segments_data.json drives backup priority**
The `counter` field is a passive usage signal — every hashtag copy in `manager`
increments it. This means `--hot` targeting in `batch-backup` is self-tuning:
high-volume series naturally surface without any manual configuration.

**Why SSH over FTP for Pi transfer**
rsync over SSH gives delta transfers (only changed files), connection reuse,
and no plaintext credentials. FTP is kept as a fallback only because vsftpd
is simpler to set up headlessly before SSH keys are exchanged.

**Why full Termux binary paths in z_backup**
Scripts sourced from `batch-backup` inherit a reduced PATH. Hardcoding
`/data/data/com.termux/files/usr/bin/zip` ensures the binary is found
regardless of how the function is invoked — interactively, from a widget,
or via Termux:Boot.
