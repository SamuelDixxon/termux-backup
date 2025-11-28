ble debugging for troubleshooting
set -x 

# --- Configuration & Path Setup ---

# The shared storage root path where the new folder will be created.
SHARED_STORAGE_ROOT="$HOME/storage/shared"

# The source path (where photos/videos are currently).
SOURCE_PATH="$SHARED_STORAGE_ROOT/DCIM/Camera" 

# Define common media extensions to search for.
MEDIA_EXTENSIONS="*.mp4 *.mov *.3gp *.webm *.mkv *.jpg *.jpeg *.png"

# --- Prerequisites Check ---

if [ ! -d "$SOURCE_PATH" ]; then
  echo "Error: Source directory '$SOURCE_PATH' not found or inaccessible."
  echo "ACTION REQUIRED: Please run 'termux-setup-storage' and grant permissions."
  set +x 
  exit 1
fi

# --- User Input ---
# Prompt user for the target folder name
TARGET_DIR_JSON=$(termux-dialog text -t "Enter NEW folder name to create in shared storage (e.g., 'Camera_Backup')")
TARGET_DIR_NAME=$(echo "$TARGET_DIR_JSON" | jq -r '.text // ""')

if [ -z "$TARGET_DIR_NAME" ]; then
  echo "No folder name entered. Exiting gracefully."
  set +x
  exit 0
fi

# 1. Define the full path for the new directory inside shared storage!
TARGET_PATH="$SHARED_STORAGE_ROOT/$TARGET_DIR_NAME"
echo "Attempting to create directory at: $TARGET_PATH"

# --- Execution: Directory Creation ---

# 2. Create the new directory.
mkdir -p "$TARGET_PATH"

if [ $? -ne 0 ]; then
    echo "CRITICAL ERROR: Failed to create target directory: $TARGET_PATH"
    set +x
    exit 1
fi

echo "SUCCESS: Directory '$TARGET_PATH' created."

# 3. Move files using find and xargs
echo "Searching for files in: $SOURCE_PATH"
find "$SOURCE_PATH" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mov" -o -name "*.3gp" -o -name "*.webm" -o -name "*.mkv" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -print0 | xargs -0 mv -t "$TARGET_PATH"

# --- Gallery Refresh Step ---
echo "Moving files complete. Now refreshing the Android Media Gallery..."

# 4. Scan both folders to ensure the Gallery is updated.
termux-media-scan -r "$TARGET_PATH"  # Make new files appear
termux-media-scan -r "$SOURCE_PATH"  # Make moved files disappear from original spot

# 5. Final Confirmation
echo "--------------------------------------------------------"
echo "✅ Operation Complete & Gallery Refreshed!"
echo "Files have been moved to: $TARGET_PATH"
echo "--------------------------------------------------------"

# Disable debugging
set +x

