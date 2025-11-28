#!/bin/bash
fastfetch

# --- Termux Storage Zip/Unzip Functions ---

# Function to BACKUP a folder from storage/shared/ to storage/shared/Export/
z_backup() {
    local folder="$1"
    local src="$HOME/storage/shared/$folder"

    # 1. Check if the source folder exists
    if [ ! -d "$src" ]; then
        echo "✗ FAILED: Folder '$folder' not found in $HOME/storage/shared"
        return 1
    fi

    # 2. Change directory and zip the contents
    cd "$src" || { echo "✗ FAILED: Could not CD into $src"; return 1; }
    
    local timestamp=$(date +%Y%m%d-%H%M)
    local zip_path="../Export/${folder}_${timestamp}.zip"
    
    # Ensure the Export directory exists
    mkdir -p "../Export"
    
    # Zip command (silently)
    zip -9 "$zip_path" * >/dev/null 2>&1

    # 3. Check zip result and provide output
    if [ $? -eq 0 ]; then
        echo "✓ BACKED UP → Export/${folder}_${timestamp}.zip"
    else
        echo "✗ FAILED: Zip operation failed for $folder"
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

