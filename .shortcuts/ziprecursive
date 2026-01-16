#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Dialog Unzip Script for Widget
# Requires: termux-api, jq, unzip
# ==========================================================

# --- Prerequisites Check ---
if ! command -v unzip &> /dev/null; then
    termux-toast "Error: 'unzip' is not installed. Run 'pkg install unzip'."
    exit 1
fi
if ! command -v jq &> /dev/null; then
    termux-toast "Error: 'jq' is not installed. Run 'pkg install jq'."
    exit 1
fi
if ! command -v termux-dialog &> /dev/null; then
    termux-toast "Error: 'termux-api' is not installed. Run 'pkg install termux-api'."
    exit 1
fi

# --- Get Arguments via Termux Dialog ---

# 1. Prompt for the file extension (e.g., zip)
EXT_JSON=$(termux-dialog text -t "Enter File Extension" -i "zip")
TARGET_EXT=$(echo "$EXT_JSON" | jq -r '.text' | tr -d '[:space:]')

# 2. Prompt for the starting directory
DIR_JSON=$(termux-dialog text -t "Enter Starting Directory" -i "$HOME/storage/downloads")
START_DIR=$(echo "$DIR_JSON" | jq -r '.text')

# Check if required values were provided
if [ -z "$TARGET_EXT" ] || [ -z "$START_DIR" ]; then
    termux-toast "Extraction cancelled by user."
    exit 0
fi

echo "--- Starting Extraction ---"
echo "Target Extension: .$TARGET_EXT"
echo "Starting Directory: $START_DIR"
echo "---------------------------"

# Change to the starting directory
cd "$START_DIR" || { termux-toast "Error: Directory '$START_DIR' not found. Check the path."; exit 1; }

# Initialize counter
count=0

# Loop through all files matching the target extension
for file in *."$TARGET_EXT"; do
    if [ -f "$file" ]; then
        count=$((count + 1))
        
        # Create the folder name by removing the extension
        base_name=$(basename -- "$file")
        folder_name="${base_name%.*}"
        
        # Create folder and attempt to extract
        mkdir -p "$folder_name"
        
        # Use case statement for extraction command
        case "$TARGET_EXT" in
            zip)
                # Unzip command for .zip files
                unzip "$file" -d "$folder_name" > /dev/null 2>&1
                COMMAND_STATUS=$?
                ;;
            # Add other extractors here if needed (e.g., rar, 7z, tar)
            # You would need to run: pkg install unrar or pkg install p7zip
            rar)
                # Assuming 'unrar' is installed
                unrar x "$file" "$folder_name" > /dev/null 2>&1
                COMMAND_STATUS=$?
                ;;
            *)
                echo "⚠️ Warning: Extractor for .$TARGET_EXT not configured. Skipping '$file'."
                continue
                ;;
        esac

        if [ "$COMMAND_STATUS" -eq 0 ]; then
            echo "✅ Extracted '$file' to '$folder_name'"
            termux-toast "Extracted: $folder_name"
        else
            echo "❌ Failed to extract '$file' (Error Code: $COMMAND_STATUS)"
        fi
    fi
done

if [ "$count" -eq 0 ]; then
    echo "No files with extension .$TARGET_EXT found in $START_DIR."
    termux-toast "No .$TARGET_EXT files found."
else
    echo "Extraction complete. $count files processed."
    termux-toast "Extraction complete. $count files processed."
fi
