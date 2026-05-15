#!/bin/bash
fastfetch

# --- Termux Storage Zip/Unzip Functions ---

# Function to BACKUP a folder from storage/shared/ to storage/shared/Export/
# Accepts either a bare folder name (e.g. "MyShoot") or a path fragment
# that may live under DCIM (e.g. "Camera"). Resolves the real path by
# searching ~/storage/shared first, then ~/storage/shared/DCIM, so zips
# always land in the single canonical Export dir regardless of source depth.
z_backup() {
    local folder="$1"
    local shared="$HOME/storage/shared"
    local export_dir="$shared/Export"
    local src=""

    # 1. Resolve source: check shared/ first, then shared/DCIM/
    if [ -d "$shared/$folder" ]; then
        src="$shared/$folder"
    elif [ -d "$shared/DCIM/$folder" ]; then
        src="$shared/DCIM/$folder"
    else
        echo "✗ FAILED: '$folder' not found in storage/shared or storage/shared/DCIM"
        return 1
    fi

    # 2. Ensure canonical Export dir exists (absolute path — never relative)
    mkdir -p "$export_dir" || { echo "✗ FAILED: Could not create Export dir"; return 1; }

    # 3. Check folder has something to zip
    local item_count
    item_count=$(find "$src" -mindepth 1 -maxdepth 3 | head -1 | wc -l)
    if [ "$item_count" -eq 0 ]; then
        echo "⚠ SKIPPED: '$folder' is empty — nothing to zip"
        return 0
    fi

    # 4. Zip recursively using absolute zip path.
    #    FIXED: was 'zip * ' which fails on empty dirs, skips subfolders,
    #    and errors on filenames with spaces. Now uses 'zip -r . ' from
    #    inside the folder — captures everything regardless of filename.
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M)
    local zip_path="$export_dir/${folder}_${timestamp}.zip"

    cd "$src" || { echo "✗ FAILED: Could not cd into $src"; return 1; }
    zip -9 -r "$zip_path" . >/dev/null 2>&1
    local zip_exit=$?

    # 5. Report result
    if [ $zip_exit -eq 0 ]; then
        local zip_size
        zip_size=$(du -sh "$zip_path" 2>/dev/null | cut -f1)
        echo "✓ BACKED UP → Export/${folder}_${timestamp}.zip (${zip_size})"
    else
        echo "✗ FAILED: Zip operation failed for $folder (exit $zip_exit)"
        rm -f "$zip_path" 2>/dev/null
        return 1
    fi
}

# Function to RESTORE the newest backup of a folder
z_restore() {
    local folder="$1"
    local target="$HOME/storage/shared/$folder"
    local export_dir="$HOME/storage/shared/Export"

    # 1. Find the newest zip file for the folder
    local zipfile
    # ls -t lists by modification time (newest first), head -n1 gets the newest
    zipfile=$(ls -t "${export_dir}/${folder}_"*.zip 2>/dev/null | head -n1)

    if [ -z "$zipfile" ]; then
        echo "✗ FAILED: No backup found for folder: $folder in $export_dir"
        return 1
    fi

    # 2. Create target directory if it doesn't exist
    mkdir -p "$target"

    # 3. Unzip the file (-o overwrites existing files)
    unzip -o "$zipfile" -d "$target" >/dev/null

    # 4. Check unzip result and provide output
    if [ $? -eq 0 ]; then
        echo "✓ RESTORED $folder ← $(basename "$zipfile")"
    else
        echo "✗ FAILED: Unzip operation failed"
    fi
}

# Aliases for easy use
alias zb='z_backup'
alias zr='z_restore'


# --- End of Termux Functions ---

alias export='cd /data/data/com.termux/files/home/storage/shared/export'
alias e='cd /data/data/com.termux/files/home/storage/shared/export'
alias cpwd='pwd | termux-clipboard-set'
alias cfile='termux-clipboard-set <'
alias ltr='ls -ltr'
alias s="cd ~/.shortcuts"
