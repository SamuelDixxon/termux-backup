#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# ~/.bashrc  --  Samuel Dixon / termux-backup
# =============================================================================
# Loaded on every Termux session. Contains:
#   - Core storage functions: z_backup, z_restore
#   - Pipeline shortcuts and aliases
#   - Segment management utilities
#   - FFmpeg media production functions
#   - Debug and dev utilities
#   - Signal processing experiments (educational / ATE crossover)
# =============================================================================

fastfetch

# =============================================================================
# CORE: z_backup / z_restore
# =============================================================================

z_backup() {
    local folder="$1"
    local shared="$HOME/storage/shared"
    local export_dir="$shared/Export"
    local src=""
    local ZIP_BIN="/data/data/com.termux/files/usr/bin/zip"
    if [ ! -x "$ZIP_BIN" ]; then
        ZIP_BIN="$(command -v zip 2>/dev/null)"
        [ -z "$ZIP_BIN" ] && echo "x zip not found -- pkg install zip" && return 1
    fi
    if [ -d "$shared/$folder" ]; then
        src="$shared/$folder"
    elif [ -d "$shared/DCIM/$folder" ]; then
        src="$shared/DCIM/$folder"
    else
        echo "x '$folder' not found in shared/ or DCIM/"
        return 1
    fi
    mkdir -p "$export_dir" || { echo "x Cannot create Export/"; return 1; }
    if [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
        echo "! SKIPPED: '$folder' is empty"
        return 0
    fi
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M)
    local zip_path="$export_dir/${folder}_${timestamp}.zip"
    cd "$src" || { echo "x Cannot cd into $src"; return 1; }
    "$ZIP_BIN" -9 -r "$zip_path" . >/dev/null 2>&1
    local zip_exit=$?
    if [ $zip_exit -eq 0 ]; then
        local zip_size
        zip_size=$(du -sh "$zip_path" 2>/dev/null | cut -f1)
        echo "OK $folder -> Export/${folder}_${timestamp}.zip ($zip_size)"
    else
        echo "x Zip failed for $folder (exit $zip_exit)"
        rm -f "$zip_path" 2>/dev/null
        return 1
    fi
}

z_restore() {
    local folder="$1"
    local target="$HOME/storage/shared/$folder"
    local export_dir="$HOME/storage/shared/Export"
    local zipfile
    zipfile=$(ls -t "${export_dir}/${folder}_"*.zip 2>/dev/null | head -n1)
    [ -z "$zipfile" ] && echo "x No backup found for: $folder" && return 1
    mkdir -p "$target"
    unzip -o "$zipfile" -d "$target" >/dev/null
    [ $? -eq 0 ] && echo "OK RESTORED $folder <- $(basename "$zipfile")" || echo "x Unzip failed"
}

alias zb='z_backup'
alias zr='z_restore'

# =============================================================================
# NAVIGATION
# =============================================================================
alias shared='cd $HOME/storage/shared'
alias dcim='cd $HOME/storage/shared/DCIM/Camera'
alias exp='cd $HOME/storage/shared/Export'
alias sc='cd $HOME/.shortcuts'
alias repo='cd $HOME/termux-backup'
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -lah'
alias ltr='ls -ltr'
alias lsize='ls -lhS'
alias ldirs='ls -d */'
alias lrecent='ls -lt | head'

# =============================================================================
# SAFETY
# =============================================================================
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'

# =============================================================================
# STORAGE / DISK
# =============================================================================
alias dfh='df -h'
alias dush='du -sh *'
alias duexp='du -sh $HOME/storage/shared/Export/*'

# =============================================================================
# CLIPBOARD
# =============================================================================
alias cpwd='pwd | termux-clipboard-set && echo "path copied"'
alias cpfile='termux-clipboard-set <'
alias clip='termux-clipboard-set'

# =============================================================================
# GIT
# =============================================================================
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -10'
alias gp='git push origin main'
alias ga='git add -A'
alias gc='git commit -m'
alias gpull='git pull origin main'
alias glog='git log --oneline --graph --decorate -20'

# =============================================================================
# DEVICE / NETWORK
# =============================================================================
alias bat='termux-battery-status | jq .'
alias myip='termux-wifi-connectioninfo | jq -r ".ip"'
alias ssid='termux-wifi-connectioninfo | jq -r ".ssid"'
alias rssi='termux-wifi-connectioninfo | jq -r ".rssi"'

# =============================================================================
# PIPELINE SHORTCUTS
# =============================================================================
alias pipeline='bash $HOME/.shortcuts/content-pipeline'
alias bb='bash $HOME/.shortcuts/batch-backup'
alias bball='bash $HOME/.shortcuts/batch-backup --all'
alias bbhot='bash $HOME/.shortcuts/batch-backup --hot'
alias bbunzipped='bash $HOME/.shortcuts/batch-backup --unzipped'
alias mgr='python3 $HOME/.shortcuts/.hidden/segment_manager.py'
alias quick='python3 $HOME/.shortcuts/.hidden/segment_manager.py --quick'
alias syncup='bash $HOME/.shortcuts/backup-all'
alias transfer='bash $HOME/.shortcuts/transfer-export'
alias voice='bash $HOME/.shortcuts/voice-command'
alias socmgr='python3 $HOME/.shortcuts/.hidden/social-manager.py'

# =============================================================================
# DEV TOOLS
# =============================================================================
alias py='python3'
alias jqp='jq . <'
alias ports='ss -tulnp'
alias psg='ps aux | grep'
alias bashreload='source ~/.bashrc && echo "bashrc reloaded"'
alias bashcheck='bash -n ~/.bashrc && echo "no syntax errors"'

# =============================================================================
# FUNCTION: seg_status
# Quick table: segment name, counter, folder on disk, zip in Export
# Flags hot segments (>=50) with no zip as !!
# =============================================================================
seg_status() {
    local DATA="$HOME/.shortcuts/.hidden/segments_data.json"
    local SHARED="$HOME/storage/shared"
    local EXPORT="$SHARED/Export"
    [ ! -f "$DATA" ] && echo "segments_data.json not found" && return 1
    printf "\n%-20s %6s %7s %8s\n" "SEGMENT" "COUNT" "FOLDER" "ZIPPED"
    printf "%-20s %6s %7s %8s\n" "-------" "-----" "------" "------"
    python3 -c "
import json, os, glob
data = json.load(open('$DATA'))
segs = sorted(data['segments'], key=lambda x: x['counter'], reverse=True)
for s in segs:
    name   = s['name']
    count  = s['counter']
    folder = os.path.isdir('$SHARED/' + name)
    zipped = len(glob.glob('$EXPORT/' + name + '_*.zip')) > 0
    flag   = '!!' if count >= 50 and not zipped else ''
    print(f'{name:<20} {count:>6}  {\"yes\" if folder else \"no\":>7}  {\"yes\" if zipped else \"NO\":>8}  {flag}')
"
    echo ""
    echo "!! = hot segment with no zip -- run: bbhot"
}
alias segstat='seg_status'

# =============================================================================
# FUNCTION: export_summary
# List all zips in Export/ sorted by date with sizes
# =============================================================================
export_summary() {
    local EXPORT="$HOME/storage/shared/Export"
    [ ! -d "$EXPORT" ] && echo "Export/ not found" && return 1
    local count total
    count=$(find "$EXPORT" -name "*.zip" | wc -l)
    total=$(du -sh "$EXPORT" 2>/dev/null | cut -f1)
    echo ""
    echo "Export/ -- $count zip(s) -- $total total"
    echo ""
    ls -lht "$EXPORT"/*.zip 2>/dev/null | \
        awk '{printf "  %-45s %6s  %s %s\n", $NF, $5, $6, $7}' | \
        sed "s|$EXPORT/||"
    echo ""
}
alias exsum='export_summary'

# =============================================================================
# FUNCTION: seg_add
# Add a segment without opening the REPL
# Usage: seg-add "name" "description" "#tag1 #tag2"
# =============================================================================
seg_add() {
    local NAME="$1" DESC="$2" TAGS="$3"
    local DATA="$HOME/.shortcuts/.hidden/segments_data.json"
    if [ -z "$NAME" ] || [ -z "$DESC" ] || [ -z "$TAGS" ]; then
        echo "Usage: seg-add <name> <description> \"#tag1 #tag2\""
        return 1
    fi
    python3 -c "
import json
data = json.load(open('$DATA'))
new_id = max(s['id'] for s in data['segments']) + 1
data['segments'].append({
    'id': new_id, 'name': '$NAME',
    'short_desc': '$DESC', 'full_desc': '$DESC',
    'counter': 0, 'hashtags': '$TAGS'.split()
})
json.dump(data, open('$DATA','w'), indent=2)
print(f'Added: $NAME (id={new_id})')
"
}
alias segadd='seg_add'

# =============================================================================
# FUNCTION: seg_set_counter
# Set a segment counter directly -- useful for mass uploads
# where you want to sync counter to actual post count without
# incrementing one by one through the manager.
# Usage: seg-set pistol 180
# =============================================================================
seg_set_counter() {
    local NAME="$1"
    local COUNT="$2"
    local DATA="$HOME/.shortcuts/.hidden/segments_data.json"
    if [ -z "$NAME" ] || [ -z "$COUNT" ]; then
        echo "Usage: seg-set <segment-name> <counter>"
        return 1
    fi
    python3 -c "
import json
data = json.load(open('$DATA'))
match = [s for s in data['segments'] if s['name'] == '$NAME']
if not match:
    print('x Segment not found: $NAME')
else:
    old = match[0]['counter']
    match[0]['counter'] = $COUNT
    json.dump(data, open('$DATA','w'), indent=2)
    print(f'Updated $NAME: {old} -> $COUNT')
"
}
alias segset='seg_set_counter'

# =============================================================================
# FUNCTION: seg_bump
# Increment a segment counter by N (default 1)
# Usage: seg-bump pistol        # +1
#        seg-bump pistol 5      # +5 (e.g. posted 5 times today)
# =============================================================================
seg_bump() {
    local NAME="$1"
    local N="${2:-1}"
    local DATA="$HOME/.shortcuts/.hidden/segments_data.json"
    [ -z "$NAME" ] && echo "Usage: seg-bump <segment-name> [N]" && return 1
    python3 -c "
import json
data = json.load(open('$DATA'))
match = [s for s in data['segments'] if s['name'] == '$NAME']
if not match:
    print('x Segment not found: $NAME')
else:
    match[0]['counter'] += $N
    json.dump(data, open('$DATA','w'), indent=2)
    print(f'$NAME counter: {match[0][\"counter\"] - $N} -> {match[0][\"counter\"]}')
"
}
alias segbump='seg_bump'

# =============================================================================
# FUNCTION: mkshot
# Create segment folder + optionally move DCIM/Camera files into it
# Usage: mkshot pistol | mkshot mcp99
# =============================================================================
mkshot() {
    local name="$1"
    local shared="$HOME/storage/shared"
    local dcim="$shared/DCIM/Camera"
    local dest="$shared/$name"
    [ -z "$name" ] && echo "Usage: mkshot <folder-name>" && return 1
    mkdir -p "$dest"
    echo "Created: $dest"
    local count
    count=$(find "$dcim" -maxdepth 1 -type f 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
        read -rp "Move $count file(s) from DCIM/Camera into $name/? (y/n): " yn
        if [ "${yn,,}" = "y" ]; then
            mv "$dcim"/* "$dest"/ 2>/dev/null
            termux-media-scan -r "$dcim" 2>/dev/null
            termux-media-scan -r "$dest" 2>/dev/null
            echo "Moved $count file(s) -> $dest/ (gallery refreshed)"
        fi
    else
        echo "DCIM/Camera is empty -- folder created, nothing moved."
    fi
}
alias mks='mkshot'

# =============================================================================
# FUNCTION: pkg_check
# Verify all required packages are installed
# =============================================================================
pkg_check() {
    local REQUIRED=(zip python jq git rsync openssh ncftp ffmpeg termux-api)
    local missing=()
    echo ""
    echo "Termux package status:"
    echo ""
    for pkg in "${REQUIRED[@]}"; do
        if command -v "$pkg" >/dev/null 2>&1 || \
           [ -x "/data/data/com.termux/files/usr/bin/$pkg" ]; then
            printf "  OK      %s\n" "$pkg"
        else
            printf "  MISSING %s\n" "$pkg"
            missing+=("$pkg")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        echo "Install: pkg install ${missing[*]}"
    else
        echo ""
        echo "All packages present."
    fi
    echo ""
}
alias pkgcheck='pkg_check'

# =============================================================================
# FUNCTION: termux_info
# One-screen device summary: battery, wifi, storage, segment count
# =============================================================================
termux_info() {
    echo ""
    echo "Device:   $(getprop ro.product.model)"
    echo "Android:  $(getprop ro.build.version.release)"
    echo "Bash:     $BASH_VERSION"
    echo ""
    echo "Storage:"
    df -h "$HOME/storage/shared" 2>/dev/null | awk 'NR==2 {
        printf "  shared/   used=%s  free=%s  total=%s\n", $3, $4, $2}'
    df -h "$HOME" 2>/dev/null | awk 'NR==2 {
        printf "  termux/   used=%s  free=%s  total=%s\n", $3, $4, $2}'
    echo ""
    echo "Battery:"
    termux-battery-status 2>/dev/null | jq -r \
        '"  " + (.percentage|tostring) + "% -- " + .status' \
        2>/dev/null || echo "  (termux-api not available)"
    echo ""
    echo "Network:"
    termux-wifi-connectioninfo 2>/dev/null | jq -r \
        '"  " + .ssid + "  " + .ip + "  " + (.rssi|tostring) + " dBm"' \
        2>/dev/null || echo "  (termux-api not available)"
    echo ""
    echo "Export/:  $(find $HOME/storage/shared/Export -name '*.zip' 2>/dev/null | wc -l) zip(s)"
    echo "Segments: $(python3 -c \
        "import json; d=json.load(open('$HOME/.shortcuts/.hidden/segments_data.json')); print(len(d['segments']))" \
        2>/dev/null || echo '?')"
    echo ""
}
alias tinfo='termux_info'

# =============================================================================
# FUNCTION: lsclip
# List folder tree + copy to clipboard for sharing/debugging
# Usage: lsclip pistol | lsclip --sizes
# =============================================================================
lsclip() {
    local target="" show_sizes=false
    local shared="$HOME/storage/shared"
    for arg in "$@"; do
        case "$arg" in
            --sizes|-s) show_sizes=true ;;
            *)          target="$arg" ;;
        esac
    done
    if [ -z "$target" ]; then
        target="$(pwd)"
    elif [ -d "$shared/$target" ]; then
        target="$shared/$target"
    elif [ ! -d "$target" ]; then
        echo "lsclip: '$target' not found"
        return 1
    fi
    local output
    output="Path: $target"$'\n'"$(date '+%Y-%m-%d %H:%M')"$'\n'"---"$'\n'
    output+="$(find "$target" -not -path '*/.*' | sort | \
        sed "s|$target/||" | sed "s|$target||" | grep -v '^$')"
    local fc dc
    fc=$(find "$target" -type f -not -path '*/.*' | wc -l)
    dc=$(find "$target" -mindepth 1 -type d -not -path '*/.*' | wc -l)
    output+=$'\n'"---"$'\n'"$fc files, $dc dirs"
    echo "$output"
    echo "$output" | termux-clipboard-set 2>/dev/null && \
        echo "" && echo "(copied to clipboard)"
}
alias lsc='lsclip'
alias lscs='lsclip --sizes'

# =============================================================================
# FUNCTION: debug_folder
# Full audit of a folder: permissions, file types, zip status, segment match
# Usage: dbf pistol
# =============================================================================
debug_folder() {
    local name="${1:-$(pwd)}"
    local shared="$HOME/storage/shared"
    local export_dir="$shared/Export"
    local data_file="$HOME/.shortcuts/.hidden/segments_data.json"
    local full_path=""
    if [ -d "$shared/$name" ]; then
        full_path="$shared/$name"
    elif [ -d "$name" ]; then
        full_path="$name"
    else
        echo "Folder not found: $name"
        return 1
    fi
    echo ""
    echo "=== debug-folder: $name ==="
    echo "Full path:   $full_path"
    echo "Permissions: $(ls -ld "$full_path" | awk '{print $1, $3, $4}')"
    local total
    total=$(find "$full_path" -maxdepth 1 -type f 2>/dev/null | wc -l)
    echo "Files (top): $total $([ "$total" -eq 0 ] && echo '-- EMPTY, z_backup will skip')"
    if [ "$total" -gt 0 ]; then
        echo "File types:"
        find "$full_path" -maxdepth 1 -type f 2>/dev/null | \
            sed 's/.*\.//' | sort | uniq -c | sort -rn | \
            while read -r count ext; do echo "  $count x .$ext"; done
    fi
    local zips
    zips=$(ls "$export_dir/$(basename "$full_path")"_*.zip 2>/dev/null | wc -l)
    if [ "$zips" -gt 0 ]; then
        echo "Zipped:      yes ($zips zip(s))"
        ls -lht "$export_dir/$(basename "$full_path")"_*.zip 2>/dev/null | \
            awk '{printf "  %s %s %s\n", $5, $6, $NF}' | \
            sed "s|$export_dir/||"
    else
        echo "Zipped:      NO"
    fi
    if [ -f "$data_file" ]; then
        local match
        match=$(python3 -c "
import json, re, sys
data = json.load(open('$data_file'))
name = '$(basename "$full_path")'
for s in data['segments']:
    if s['name'] == name or re.match(r'^' + re.escape(s['name']) + r'[0-9]+$', name):
        print(f\"matched: {s['name']} (counter={s['counter']})\")
        sys.exit(0)
print('no segment match')
" 2>/dev/null)
        echo "Segment:     $match"
    fi
    echo ""
}
alias dbf='debug_folder'

# =============================================================================
# FUNCTION: gc_empty
# Remove empty directories from shared/ (GUI-delete leaves shells behind)
# Usage: gc-empty | gc-empty --delete | gc-empty --delete --dcim
# =============================================================================
gc_empty() {
    local do_delete=false check_dcim=false
    local shared="$HOME/storage/shared"
    for arg in "$@"; do
        case "$arg" in
            --delete|-d) do_delete=true ;;
            --dcim)      check_dcim=true ;;
        esac
    done
    local NEVER="Export|Android|Alarms|Audiobooks|Books|Documents|Download"
    NEVER+="|Movies|Music|Notifications|Podcasts|Recordings|Ringtones"
    NEVER+="|SamsungNotes|RW_LIB|DCIM|Pictures|Book"
    echo ""
    $do_delete && echo "=== gc-empty: DELETING ===" || echo "=== gc-empty: DRY RUN ==="
    echo ""
    local found=0 removed=0
    while IFS= read -r -d '' dir; do
        local name fc
        name=$(basename "$dir")
        echo "$name" | grep -qE "^($NEVER)$" && continue
        fc=$(find "$dir" -type f 2>/dev/null | wc -l)
        if [ "$fc" -eq 0 ]; then
            ((found++)) || true
            if $do_delete; then
                rm -rf "$dir" 2>/dev/null && \
                    echo "  REMOVED  $name/" && ((removed++)) || true
            else
                echo "  EMPTY    $name/  (would remove)"
            fi
        fi
    done < <(find "$shared" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    if $check_dcim; then
        while IFS= read -r -d '' dir; do
            local fc name
            fc=$(find "$dir" -type f 2>/dev/null | wc -l)
            name=$(basename "$dir")
            if [ "$fc" -eq 0 ]; then
                ((found++)) || true
                $do_delete && rm -rf "$dir" 2>/dev/null && \
                    echo "  REMOVED  DCIM/$name/" && ((removed++)) || true
                $do_delete || echo "  EMPTY    DCIM/$name/"
            fi
        done < <(find "$shared/DCIM" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    fi
    echo ""
    $do_delete && echo "Removed: $removed empty dir(s)" && \
        [ "$removed" -gt 0 ] && termux-media-scan -r "$shared" 2>/dev/null && \
        echo "Gallery refreshed."
    $do_delete || echo "Found: $found empty dir(s)  -- run with --delete to remove"
    echo ""
}
alias gcempty='gc_empty'
alias gcd='gc_empty --delete'

# =============================================================================
# FUNCTION: clean_termux
# Clean 5 junk zones: XDG trash, apt cache, tmp, pip cache, FUSE trash
# Usage: clean-termux | clean-termux --dry | clean-termux --force
# =============================================================================
clean_termux() {
    local dry=false confirm=true
    for arg in "$@"; do
        case "$arg" in
            --dry)   dry=true ;;
            --force) confirm=false ;;
        esac
    done
    echo ""
    $dry && echo "=== CLEAN-TERMUX [dry run] ===" || echo "=== CLEAN-TERMUX ==="
    echo ""
    declare -a ZONES=(
        "XDG Trash|$HOME/.local/share/Trash|"
        "apt cache|$PREFIX/var/cache/apt/archives|*.deb"
        "Termux tmp|$PREFIX/tmp|"
        "pip cache|$HOME/.cache/pip|"
        "FUSE trash|$HOME/storage/shared|.Trash-*"
    )
    local total_bytes=0
    declare -a ZONE_SIZES=()
    for zone in "${ZONES[@]}"; do
        IFS='|' read -r label path pattern <<< "$zone"
        local size_bytes=0 size_str="0K"
        if [ -d "$path" ]; then
            if [ -n "$pattern" ]; then
                size_bytes=$(find "$path" -maxdepth 1 -name "$pattern" \
                    -exec du -sb {} + 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
                size_str="${size_bytes}B"
            else
                size_str=$(du -sh "$path" 2>/dev/null | cut -f1)
                size_bytes=$(du -sb "$path" 2>/dev/null | cut -f1)
            fi
        fi
        ZONE_SIZES+=("$size_bytes")
        total_bytes=$((total_bytes + size_bytes))
        printf "  %-14s  %6s  %s\n" "$label" "$size_str" "$path"
    done
    local total_hr
    [ "$total_bytes" -gt 1048576 ] && \
        total_hr=$(echo "$total_bytes" | awk '{printf "%.1fM", $1/1048576}') || \
        total_hr=$(echo "$total_bytes" | awk '{printf "%.0fK", $1/1024}')
    echo ""
    echo "  Total reclaimable: $total_hr"
    echo ""
    $dry && echo "Dry run -- nothing deleted." && return 0
    [ "$total_bytes" -eq 0 ] && echo "Already clean." && return 0
    $confirm && read -rp "Wipe all zones? (yes/no): " answer
    [[ "${answer:-yes}" != "yes" ]] && echo "Cancelled." && return 0
    for zone in "${ZONES[@]}"; do
        IFS='|' read -r label path pattern <<< "$zone"
        [ ! -d "$path" ] && continue
        if [ -n "$pattern" ]; then
            find "$path" -maxdepth 1 -name "$pattern" -exec rm -rf {} + 2>/dev/null
        else
            find "$path" -mindepth 1 -delete 2>/dev/null
        fi
        printf "  OK  %s cleared\n" "$label"
    done
    command -v apt-get >/dev/null 2>&1 && \
        apt-get autoremove -y --purge >/dev/null 2>&1 && \
        apt-get autoclean >/dev/null 2>&1 && \
        echo "  OK  apt orphans cleaned"
    echo ""
    echo "Done -- $total_hr freed."
    echo ""
}
alias clean-termux='clean_termux'

# =============================================================================
# FUNCTION: empty_gallery_trash
# Remove Android gallery trash (MediaStore IS_TRASHED dotfiles)
# Bypasses the 30-day hold. Fires termux-media-scan after delete.
# Usage: empty-gallery-trash | --dry | --force
# =============================================================================
empty_gallery_trash() {
    local dry=false confirm=true
    for arg in "$@"; do
        case "$arg" in
            --dry)   dry=true ;;
            --force) confirm=false ;;
        esac
    done
    local SHARED="$HOME/storage/shared"
    declare -a SEARCH_DIRS=("$SHARED/DCIM" "$SHARED/Pictures" \
                            "$SHARED/Movies" "$SHARED/Download")
    echo ""
    $dry && echo "=== GALLERY TRASH [dry run] ===" || echo "=== GALLERY TRASH ==="
    echo ""
    local TRASH_LIST
    TRASH_LIST=$(find "${SEARCH_DIRS[@]}" -maxdepth 3 -name ".*" -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
           -iname "*.heic" -o -iname "*.mp4" -o -iname "*.mov" \) \
        2>/dev/null)
    if [ -z "$TRASH_LIST" ]; then
        echo "Gallery trash is empty."
        return 0
    fi
    local file_count size_bytes
    file_count=$(echo "$TRASH_LIST" | wc -l)
    size_bytes=$(echo "$TRASH_LIST" | xargs du -sb 2>/dev/null | \
                 awk '{sum+=$1} END{print sum+0}')
    echo "  Found $file_count trashed file(s)"
    $dry && echo "Dry run -- nothing deleted." && return 0
    $confirm && {
        echo "  These bypass the 30-day recovery window."
        read -rp "  Delete all $file_count files? (yes/no): " answer
        [[ "$answer" != "yes" ]] && echo "Cancelled." && return 0
    }
    declare -A SCAN_DIRS
    local deleted=0 failed=0
    while IFS= read -r f; do
        local dir
        dir=$(dirname "$f")
        if rm -f "$f" 2>/dev/null; then
            echo "  OK  $(basename "$f")"
            SCAN_DIRS["$dir"]=1
            ((deleted++)) || true
        else
            echo "  x   $(basename "$f") (failed)"
            ((failed++)) || true
        fi
    done <<< "$TRASH_LIST"
    for dir in "${!SCAN_DIRS[@]}"; do
        termux-media-scan -r "$dir" 2>/dev/null
    done
    echo ""
    echo "Deleted: $deleted  Failed: $failed"
}
alias empty-gallery-trash='empty_gallery_trash'

# =============================================================================
# FFMPEG: TAPESTRY / GRID SCRIPT
# =============================================================================
# String multiple clips from a segment folder into a single video.
# Two modes:
#   --concat   Sequential: clip1 -> clip2 -> clip3 (reel style)
#   --grid     2x2 or NxN grid: all clips playing simultaneously
#              (great for showing volume/repetition at a glance)
#
# EDUCATIONAL CONCEPT:
#   The concat mode is a direct application of the ffmpeg concat demuxer --
#   same mechanism used in broadcast automation for playlist-based playout.
#   The grid uses the xstack filter which maps inputs to a spatial layout,
#   identical to multi-camera monitoring in ATE station displays.
#
# Usage:
#   tapestry pistol              # concat all mp4s in shared/pistol/
#   tapestry pistol --grid       # 2x2 grid of first 4 clips
#   tapestry skip --concat --max 10   # concat first 10 clips
#   tapestry mcp96 --grid --cols 3    # 3-column grid
# =============================================================================
tapestry() {
    local segment="$1"
    shift
    local mode="concat"
    local max_clips=20
    local cols=2
    local shared="$HOME/storage/shared"
    local src="$shared/$segment"
    local out_dir="$shared/Export"
    local FFMPEG="/data/data/com.termux/files/usr/bin/ffmpeg"

    for arg in "$@"; do
        case "$arg" in
            --grid)    mode="grid" ;;
            --concat)  mode="concat" ;;
            --max)     shift; max_clips="$1" ;;
            --cols)    shift; cols="$1" ;;
        esac
    done

    [ -z "$segment" ] && echo "Usage: tapestry <segment> [--grid|--concat] [--max N] [--cols N]" && return 1
    [ ! -d "$src" ] && echo "x Folder not found: $src" && return 1
    [ ! -x "$FFMPEG" ] && echo "x ffmpeg not found -- pkg install ffmpeg" && return 1

    local timestamp
    timestamp=$(date +%Y%m%d-%H%M)
    local out_file="$out_dir/${segment}_tapestry_${mode}_${timestamp}.mp4"

    # Collect mp4 files sorted by modification time (chronological order)
    mapfile -t CLIPS < <(find "$src" -maxdepth 1 -name "*.mp4" -o -name "*.mov" \
                         2>/dev/null | sort | head -"$max_clips")

    if [ "${#CLIPS[@]}" -eq 0 ]; then
        echo "x No mp4/mov files found in $src"
        return 1
    fi

    echo "Tapestry: $segment  mode=$mode  clips=${#CLIPS[@]}"
    echo "Output:   $out_file"
    echo ""

    mkdir -p "$out_dir"

    if [ "$mode" = "concat" ]; then
        # -- CONCAT MODE ----------------------------------------------------
        # Write a temporary concat list file (ffmpeg concat demuxer format)
        # Each line: file '/path/to/clip.mp4'
        # This is faster than re-encoding -- uses stream copy where possible.
        local list_file
        list_file=$(mktemp /data/data/com.termux/files/home/.cache/tapestry_XXXXXX.txt)
        for clip in "${CLIPS[@]}"; do
            echo "file '$clip'" >> "$list_file"
        done

        echo "Concatenating ${#CLIPS[@]} clips..."
        "$FFMPEG" -f concat -safe 0 -i "$list_file" \
            -c:v libx264 -preset fast -crf 23 \
            -c:a aac -b:a 128k \
            -movflags +faststart \
            "$out_file" -y 2>/dev/null

        rm -f "$list_file"

    else
        # -- GRID MODE ------------------------------------------------------
        # xstack filter: places N inputs in an NxN grid
        # Each input is scaled to a common resolution first (scale2ref).
        # Grid layout string: 0_0|w0_0|0_h0|w0_h0 for 2x2
        #
        # EDUCATIONAL NOTE:
        #   xstack is the ffmpeg equivalent of a video matrix switcher.
        #   In ATE, you use a similar concept for multi-site parallel testing:
        #   each DUT feeds one "cell" of the monitoring grid.
        #   Here each clip is a "DUT" and the grid is your performance matrix.

        local n="${#CLIPS[@]}"
        local rows=$(( (n + cols - 1) / cols ))
        local cell_w=480
        local cell_h=270

        # Build filter complex string
        local filter=""
        local inputs=""
        for i in "${!CLIPS[@]}"; do
            inputs+="-i '${CLIPS[$i]}' "
            filter+="[$i:v]scale=${cell_w}:${cell_h}:force_original_aspect_ratio=decrease,pad=${cell_w}:${cell_h}[v$i];"
        done

        # Build xstack layout
        local layout=""
        for ((row=0; row<rows; row++)); do
            for ((col=0; col<cols; col++)); do
                local idx=$((row * cols + col))
                [ "$idx" -ge "$n" ] && break
                local x="$((col * cell_w))"
                local y="$((row * cell_h))"
                layout+="${x}_${y}|"
            done
        done
        layout="${layout%|}"  # remove trailing pipe

        # Build input labels for xstack
        local stack_inputs=""
        for i in "${!CLIPS[@]}"; do
            stack_inputs+="[v$i]"
        done

        local total_w=$((cols * cell_w))
        local total_h=$((rows * cell_h))
        filter+="${stack_inputs}xstack=inputs=${n}:layout=${layout}[out]"

        echo "Building ${cols}x${rows} grid (${n} clips)..."
        eval "$FFMPEG $inputs \
            -filter_complex \"$filter\" \
            -map \"[out]\" \
            -c:v libx264 -preset fast -crf 23 \
            -movflags +faststart \
            \"$out_file\" -y 2>/dev/null"
    fi

    if [ -f "$out_file" ]; then
        local size
        size=$(du -sh "$out_file" | cut -f1)
        echo "OK Tapestry complete: $out_file ($size)"
        termux-media-scan "$out_file" 2>/dev/null
    else
        echo "x Tapestry failed -- check ffmpeg output"
        return 1
    fi
}

# =============================================================================
# FFMPEG: THUMBNAIL BURNER
# =============================================================================
# Burn a text label onto the first N seconds of a video.
# Reads segment name + counter from session.json if available,
# otherwise prompts.
#
# Label format: "Pistol 181" (capitalised name + counter)
# Font: uses Android system font (Roboto) or fallback
#
# EDUCATIONAL CONCEPT:
#   drawtext filter = real-time video compositing.
#   Same technique used in broadcast lower-thirds and OSD overlays.
#   In ATE: analogous to burning a test ID onto a captured waveform image.
#
# Usage:
#   burn-thumb ~/storage/shared/pistol/clip.mp4
#   burn-thumb ~/storage/shared/pistol/clip.mp4 --label "Pistol 181"
#   burn-thumb ~/storage/shared/pistol/clip.mp4 --dur 5
# =============================================================================
burn_thumb() {
    local input="$1"
    shift
    local label=""
    local dur=3
    local FFMPEG="/data/data/com.termux/files/usr/bin/ffmpeg"

    for arg in "$@"; do
        case "$arg" in
            --label) shift; label="$1" ;;
            --dur)   shift; dur="$1" ;;
        esac
    done

    [ -z "$input" ] && echo "Usage: burn-thumb <video.mp4> [--label \"Text\"] [--dur N]" && return 1
    [ ! -f "$input" ] && echo "x File not found: $input" && return 1
    [ ! -x "$FFMPEG" ] && echo "x ffmpeg not found -- pkg install ffmpeg" && return 1

    # Auto-read label from session.json if not provided
    if [ -z "$label" ]; then
        local SESSION="$HOME/.shortcuts/.hidden/session.json"
        if [ -f "$SESSION" ]; then
            local seg count
            seg=$(python3 -c "import json; d=json.load(open('$SESSION')); print(d.get('segment',''))")
            count=$(python3 -c "import json; d=json.load(open('$SESSION')); print(d.get('counter',''))")
            [ -n "$seg" ] && label="$(echo "${seg:0:1}" | tr '[:lower:]' '[:upper:]')${seg:1} $count"
        fi
    fi

    [ -z "$label" ] && read -rp "Label text (e.g. Pistol 181): " label
    [ -z "$label" ] && echo "x No label provided" && return 1

    local dir base ext
    dir=$(dirname "$input")
    base=$(basename "$input" | sed 's/\.[^.]*$//')
    ext="${input##*.}"
    local output="${dir}/${base}_labeled.${ext}"

    # Font path: try system Roboto first, fall back to any available font
    local font_path="/system/fonts/Roboto-Bold.ttf"
    [ ! -f "$font_path" ] && font_path="/system/fonts/DroidSans-Bold.ttf"
    [ ! -f "$font_path" ] && font_path="/data/data/com.termux/files/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

    echo "Burning label: '$label' onto first ${dur}s of video"
    echo "Output: $output"

    "$FFMPEG" -i "$input" \
        -vf "drawtext=text='$label':
             fontfile='$font_path':
             fontsize=72:
             fontcolor=white:
             x=(w-text_w)/2:
             y=h-text_h-40:
             shadowcolor=black:
             shadowx=3:
             shadowy=3:
             enable='between(t,0,$dur)'" \
        -c:v libx264 -preset fast -crf 22 \
        -c:a copy \
        -movflags +faststart \
        "$output" -y 2>/dev/null

    if [ -f "$output" ]; then
        local size
        size=$(du -sh "$output" | cut -f1)
        echo "OK $output ($size)"
        termux-media-scan "$output" 2>/dev/null
    else
        echo "x burn-thumb failed"
        return 1
    fi
}
alias burnthumb='burn_thumb'

# =============================================================================
# FFMPEG: AUDIO TOOLS (signal processing / ATE crossover)
# =============================================================================
# Extract audio, analyse spectrum, compute basic signal metrics.
# Educational bridge between content creation and your ATE background.

# -- Extract audio from video --------------------------------------------------
# Usage: extract-audio clip.mp4
extract_audio() {
    local input="$1"
    [ -z "$input" ] && echo "Usage: extract-audio <video.mp4>" && return 1
    local output="${input%.*}.aac"
    ffmpeg -i "$input" -vn -c:a copy "$output" -y 2>/dev/null
    echo "OK $output"
}
alias extractaudio='extract_audio'

# -- Probe media file (codec, resolution, duration, bitrate) ------------------
# Usage: probe clip.mp4
probe_media() {
    local input="$1"
    [ -z "$input" ] && echo "Usage: probe <file>" && return 1
    ffprobe -v quiet -print_format json -show_streams -show_format \
        "$input" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
fmt = d.get('format', {})
print(f\"File:      {fmt.get('filename','?')}\")
print(f\"Duration:  {float(fmt.get('duration',0)):.1f}s\")
print(f\"Size:      {int(fmt.get('size',0))//1024} KB\")
print(f\"Bitrate:   {int(fmt.get('bit_rate',0))//1000} kbps\")
for s in d.get('streams',[]):
    if s.get('codec_type') == 'video':
        print(f\"Video:     {s.get('codec_name')} {s.get('width')}x{s.get('height')} {s.get('r_frame_rate')} fps\")
    elif s.get('codec_type') == 'audio':
        print(f\"Audio:     {s.get('codec_name')} {s.get('sample_rate')}Hz {s.get('channels')}ch\")
"
}
alias probe='probe_media'

# -- Compress video for upload (reduce file size while keeping quality) --------
# Usage: compress-vid clip.mp4 | compress-vid clip.mp4 --crf 28
compress_vid() {
    local input="$1"
    local crf=26
    [ "$3" = "--crf" ] && crf="$4"
    [ -z "$input" ] && echo "Usage: compress-vid <video.mp4> [--crf N]" && return 1
    local output="${input%.*}_compressed.mp4"
    echo "Compressing $input (CRF=$crf)..."
    ffmpeg -i "$input" -c:v libx264 -preset slow -crf "$crf" \
        -c:a aac -b:a 128k -movflags +faststart \
        "$output" -y 2>/dev/null
    [ -f "$output" ] && echo "OK $output ($(du -sh "$output" | cut -f1))" || echo "x Failed"
}
alias compvid='compress_vid'

# -- Generate waveform image from audio (ATE-style signal visualisation) ------
# Usage: waveform clip.mp4
waveform_img() {
    local input="$1"
    [ -z "$input" ] && echo "Usage: waveform <audio/video file>" && return 1
    local output="${input%.*}_waveform.png"
    ffmpeg -i "$input" -filter_complex \
        "showwavespic=s=1280x200:colors=#1D9E75" \
        -frames:v 1 "$output" -y 2>/dev/null
    [ -f "$output" ] && echo "OK $output" || echo "x Failed"
}
alias waveform='waveform_img'

# =============================================================================
# LEGACY ALIASES (kept for compatibility)
# =============================================================================
alias export='cd /data/data/com.termux/files/home/storage/shared/Export'
alias e='cd /data/data/com.termux/files/home/storage/shared/Export'
alias cpfile='termux-clipboard-set <'

# =============================================================================
# END
# =============================================================================
