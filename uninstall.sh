#!/system/bin/sh
# ─────────────────────────────────────────────
# Sortify Xtended v1.0 - uninstall.sh
# Runs when module is uninstalled
# Author: Imnotshashwat
# ─────────────────────────────────────────────

MODDIR="/data/adb/modules/sortify_xtended"
CONF="$MODDIR/sortify.conf"
BASE="/sdcard/Download"

log() { echo "[Sortify Xtended] $1"; }

log "Starting uninstall..."

# ─── validate watch path (safety net) ──────
is_valid_watch_dir() {
    vdir="$1"
    [ -z "$vdir" ] && return 1
    case "$vdir" in *..*) return 1 ;; esac
    clean_vdir=$(echo "$vdir" | sed 's:/*$::')
    case "$clean_vdir" in
        /sdcard|/storage|/storage/emulated|/storage/emulated/0) return 1 ;;
        /sdcard/Android*|/storage/emulated/0/Android*|/storage/emulated/*/Android*|\
        /sdcard/DCIM*|/storage/emulated/0/DCIM*|\
        /data*|/system*|/proc*|/sys*|/dev*|/apex*|/vendor*) return 1 ;;
        /sdcard/*|/storage/*) return 0 ;;
        *) return 1 ;;
    esac
}

# ─── load conf to know watch dirs ──────────
WATCH_DIRS="$BASE"
[ -f "$CONF" ] && WATCH_DIRS=$(grep "^WATCH_DIRS=" "$CONF" | cut -d= -f2)
WATCH_DIRS="${WATCH_DIRS:-$BASE}"

# ─── revert sorted files ───────────────────
revert_dir() {
    dir="$1"
    log "Reverting: $dir"

    safe_mv() {
        src_file="$1"
        dest_dir="$2"
        base_name=$(basename "$src_file")
        dest_file="$dest_dir/$base_name"
        if [ -f "$dest_file" ]; then
            i=1
            case "$base_name" in
                *.*)
                    while [ -f "$dest_dir/${base_name%.*}-$i.${base_name##*.}" ]; do
                        i=$((i + 1))
                    done
                    new_name="${base_name%.*}-$i.${base_name##*.}"
                    ;;
                *)
                    while [ -f "$dest_dir/${base_name}-$i" ]; do
                        i=$((i + 1))
                    done
                    new_name="${base_name}-$i"
                    ;;
            esac
            log "  - Renaming conflict: $(basename "$src_file") -> $new_name"
            mv -f "$src_file" "$dest_dir/$new_name"
        else
            mv -f "$src_file" "$dest_file"
        fi
    }

    # only revert Sortify's known category folders — never touch user's own folders
    for folder in Documents Images Audio "Audio/Music" Videos Archives Apps Code Duplicates Others; do
        if [ -d "$dir/$folder" ]; then
            find "$dir/$folder" -type f | while read -r file; do
                safe_mv "$file" "$dir"
            done
            find "$dir/$folder" -depth -type d -exec rmdir {} + 2>/dev/null
            rmdir "$dir/$folder" 2>/dev/null
            log "Removed: $folder"
        fi
    done
    # revert custom folder rules
    grep "^CUSTOM_FOLDER_" "$CONF" 2>/dev/null | while IFS='=' read -r key _; do
        folder="${key#CUSTOM_FOLDER_}"
        if [ -d "$dir/$folder" ]; then
            find "$dir/$folder" -type f | while read -r file; do
                safe_mv "$file" "$dir"
            done
            find "$dir/$folder" -depth -type d -exec rmdir {} + 2>/dev/null
            rmdir "$dir/$folder" 2>/dev/null
            log "Removed custom: $folder"
        fi
    done
}

IFS=','
for dir in $WATCH_DIRS; do
    IFS=' '
    dir=$(echo "$dir" | xargs)
    if [ -d "$dir" ] && is_valid_watch_dir "$dir"; then
        revert_dir "$dir"
    fi
    IFS=','
done
IFS=' '

# ─── clean up module data files ────────────
log "Cleaning up..."
rm -f "$MODDIR/sortify.log"
rm -f "$MODDIR/sortify.stats"
rm -f "$MODDIR/sortify.history"
rm -f "$MODDIR/sortify.conf"
rm -f "$MODDIR/webroot/sortify.conf"
rm -f "$MODDIR/webroot/sortify.log"
rm -f "$MODDIR/webroot/sortify.stats"
rm -f "$MODDIR/webroot/sortify.history"
rm -f "/tmp/sortify_xtended.lock"

# clean up Sortify log/conf mirror in Download
rm -rf "/sdcard/Download/Sortify" 2>/dev/null
log "Sortify Xtended uninstalled cleanly."
