# Termux Dev-Ops: Multi-Device Sync Ecosystem

A robust, distributed workflow for high-volume content creators managing multiple mobile devices (**Samsung S23+**, **Google Pixel 9a**, **ZFlip7**).

## 🏗 System Architecture

This system utilizes a **Shadow Repository** strategy to manage Termux scripts and environment configurations across hardware.

### The "Mirror" Logic (System Level)
Unlike standard backups, this system uses `rsync --delete` to enforce a bidirectional "Source of Truth":
1.  **Local Deletions:** If a script is deleted in `~/.shortcuts`, running `backup-all` physically removes it from the Git staging area (`~/termux-backup`) and pushes the deletion to GitHub.
2.  **Global Deletions:** When other devices run `sync-in`, the `git reset --hard` and `rsync --delete` flags ensure ghost files are purged from the local handset.

## 🛠 Component Breakdown

### Core Scripts (~/.shortcuts/)
* **backup-all**: Enforces a 1:1 mirror from the device system to the Cloud. Captures additions, edits, and deletions.
* **sync-in**: Forces the device to match the Cloud exactly. Wipes local "junk" scripts and updates environment variables.
* **manager**: A Python-based CRUD interface for the Content Segment database.
* **org-camera-album**: Automates the movement and gallery-refreshing of raw media files.
* **iir-log**: A background service logging detailed battery telemetry to CSV.

### Data Engine (.hidden/)
* **segments_data.json**: The central database for tracking video series counters and optimized hashtag groups.
* **segment_manager2.py**: The logic engine for maintaining metadata consistency across all three phones.

## 🚀 Deployment

### Prerequisites
```bash
pkg install rsync git termux-api python jq
