#!/system/bin/sh
# ─────────────────────────────────────────────
# Sortify Xtended v1.0 - service.sh
# Handles: background loop, pause/resume,
#          revert, direct WebUI calls
# Author: Imnotshashwat
# ─────────────────────────────────────────────

MODDIR="/data/adb/modules/sortify_xtended"
CONF="$MODDIR/sortify.conf"
LOG="$MODDIR/sortify.log"
STATS="$MODDIR/sortify.stats"
HISTORY="$MODDIR/sortify.history"
WEBROOT="$MODDIR/webroot"

# ─── logging ───────────────────────────────
SDCARD_LOG_DIR="/sdcard/Download/Sortify"
SDCARD_LOG="$SDCARD_LOG_DIR/sortify.log"

log_msg() {
    [ ! -f "$LOG" ] && touch "$LOG" && chmod 666 "$LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    mkdir -p "$SDCARD_LOG_DIR" 2>/dev/null
    cp "$LOG" "$SDCARD_LOG" 2>/dev/null
    chmod 666 "$SDCARD_LOG" 2>/dev/null
}

# ─── mirror conf to sdcard ─────────────────
mirror_conf() {
    mkdir -p "$SDCARD_LOG_DIR" 2>/dev/null
    cp "$CONF" "$SDCARD_LOG_DIR/sortify.conf" 2>/dev/null
    chmod 666 "$SDCARD_LOG_DIR/sortify.conf" 2>/dev/null
    cp "$CONF" "$WEBROOT/sortify.conf" 2>/dev/null
    chmod 666 "$WEBROOT/sortify.conf" 2>/dev/null
}

# ─── load conf ─────────────────────────────
load_conf() {
    [ -f "$CONF" ] && . "$CONF"
    INTERVAL="${INTERVAL:-300}"
    SCHEDULE="${SCHEDULE:-always}"
    SCHEDULE_FROM="${SCHEDULE_FROM:-}"
    SCHEDULE_TO="${SCHEDULE_TO:-}"
    WATCH_DIRS="${WATCH_DIRS:-/sdcard/Download}"
    PAUSED_UNTIL="${PAUSED_UNTIL:-0}"
    STOPPED="${STOPPED:-false}"
}

# ─── write default conf ────────────────────
write_default_conf() {
    cat > "$CONF" << 'EOF'
# Sortify Xtended v1.0
VERSION=1
INTERVAL=300
SCHEDULE=always
SCHEDULE_FROM=
SCHEDULE_TO=
WATCH_DIRS=/sdcard/Download
PAUSED_UNTIL=0
STOPPED=false
SORTING=false
CAT_DOCUMENTS=true
CAT_IMAGES=true
CAT_AUDIO=true
CAT_VIDEOS=true
CAT_ARCHIVES=true
CAT_APPS=true
CAT_CODE=true
CAT_DUPLICATES=true
CAT_OTHERS=true
EXT_DOCUMENTS=
EXT_IMAGES=
EXT_AUDIO=
EXT_VIDEOS=
EXT_ARCHIVES=
EXT_APPS=
EXT_CODE=
EXCLUDE_EXTENSIONS=
EXCLUDE_FILES=
EOF
    chmod 666 "$CONF"
    mirror_conf
}

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

# ─── migration from original Sortify ────────
migrate_original_sortify() {
    for old_base in "/sdcard/Sortify" "/sdcard/Download/Sortify"; do
        [ -d "$old_base" ] || continue
        has_migrated=false
        for cat_dir in Documents Images Audio "Audio/Music" Videos Archives Apps Others Duplicates Code; do
            target_cat="$old_base/$cat_dir"
            if [ -d "$target_cat" ]; then
                find "$target_cat" -type f 2>/dev/null | while read -r mfile; do
                    [ -f "$mfile" ] || continue
                    mname=$(basename "$mfile")
                    dest="/sdcard/Download/$mname"
                    if [ -e "$dest" ]; then
                        i=1
                        base_m="${mname%.*}"
                        ext_m="${mname##*.}"
                        case "$mname" in
                            *.*)
                                while [ -e "/sdcard/Download/${base_m}-$i.${ext_m}" ]; do
                                    i=$((i + 1))
                                done
                                dest="/sdcard/Download/${base_m}-$i.${ext_m}"
                                ;;
                            *)
                                while [ -e "/sdcard/Download/${mname}-$i" ]; do
                                    i=$((i + 1))
                                done
                                dest="/sdcard/Download/${mname}-$i"
                                ;;
                        esac
                    fi
                    mv -f "$mfile" "$dest"
                done
                find "$target_cat" -depth -type d -exec rmdir {} + 2>/dev/null
                rmdir "$target_cat" 2>/dev/null
                has_migrated=true
            fi
        done
        if [ "$old_base" = "/sdcard/Sortify" ]; then
            rmdir "/sdcard/Sortify" 2>/dev/null
        fi
        [ "$has_migrated" = "true" ] && log_msg "[Migration] Migrated files from $old_base into /sdcard/Download"
    done
}

# ─── revert all sorted files ───────────────
revert_dir() {
    dir="$1"
    log_msg "Reverting: $dir"

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
            log_msg "[Revert] Renaming conflict: $(basename "$src_file") -> $new_name"
            mv -f "$src_file" "$dest_dir/$new_name"
        else
            mv -f "$src_file" "$dest_file"
        fi
    }

    # only revert Sortify's known category folders — never touch user's own folders
    total_restored=0
    for folder in Documents Images Audio "Audio/Music" Videos Archives Apps Code Duplicates Others; do
        if [ -d "$dir/$folder" ]; then
            count=$(find "$dir/$folder" -type f | wc -l | tr -d ' ')
            find "$dir/$folder" -type f | while read -r file; do
                safe_mv "$file" "$dir"
            done
            # safely remove empty directories without deleting un-moved files
            find "$dir/$folder" -depth -type d -exec rmdir {} + 2>/dev/null
            rmdir "$dir/$folder" 2>/dev/null
            log_msg "[Reverted] $folder/ — $count files restored"
            total_restored=$((total_restored + count))
        fi
    done
    # revert custom folder rules
    grep "^CUSTOM_FOLDER_" "$CONF" 2>/dev/null | while IFS='=' read -r key _; do
        folder="${key#CUSTOM_FOLDER_}"
        if [ -d "$dir/$folder" ]; then
            count=$(find "$dir/$folder" -type f | wc -l | tr -d ' ')
            find "$dir/$folder" -type f | while read -r file; do
                safe_mv "$file" "$dir"
            done
            find "$dir/$folder" -depth -type d -exec rmdir {} + 2>/dev/null
            rmdir "$dir/$folder" 2>/dev/null
            log_msg "[Reverted] $folder/ — $count files restored (custom)"
            total_restored=$((total_restored + count))
        fi
    done
    log_msg "=== Revert done. Total: $total_restored files restored ==="
    log_msg "=== Paused after revert ===" 
}

revert_all() {
    load_conf
    log_msg "=== Revert started ==="
    IFS=','
    for dir in $WATCH_DIRS; do
        IFS=' '
        dir=$(echo "$dir" | xargs)
        if [ -d "$dir" ]; then
            if is_valid_watch_dir "$dir"; then
                revert_dir "$dir"
            else
                log_msg "[BLOCKED] Protected path skipped in revert: $dir"
            fi
        fi
        IFS=','
    done
    IFS=' '
    # mark as stopped in conf
    sed -i 's/^STOPPED=.*/STOPPED=true/' "$CONF"
    mirror_conf
}

# ─── direct WebUI calls ────────────────────
case "$1" in
    revert)
        revert_all
        exit 0
        ;;
    resume)
        sed -i 's/^STOPPED=.*/STOPPED=false/' "$CONF"
        sed -i 's/^PAUSED_UNTIL=.*/PAUSED_UNTIL=0/' "$CONF"
        mirror_conf
        log_msg "=== Resumed by user ==="
        exit 0
        ;;
    undo)
        load_conf
        if [ ! -f "$HISTORY" ] || [ ! -s "$HISTORY" ]; then
            log_msg "[Undo] Nothing to undo"
            exit 0
        fi
        last_ts=$(tail -n 1 "$HISTORY" | cut -d'|' -f1)
        grep "^${last_ts}|" "$HISTORY" | awk '{a[NR]=$0} END{for(i=NR;i>=1;i--)print a[i]}' | \
        while IFS='|' read -r ts src dest; do
            [ -z "$dest" ] && continue
            if [ -f "$dest" ]; then
                mkdir -p "$(dirname "$src")" 2>/dev/null
                mv -f "$dest" "$src" 2>/dev/null
                log_msg "[Undo] Restored: $(basename "$dest")"
            fi
        done
        grep -v "^${last_ts}|" "$HISTORY" > "$HISTORY.tmp" 2>/dev/null
        mv "$HISTORY.tmp" "$HISTORY"
        log_msg "[Undo] Done"
        exit 0
        ;;
esac

# ─── wait for storage ──────────────────────
until [ -d "/sdcard/Download" ]; do sleep 5; done

# ─── init conf if missing ──────────────────
[ ! -f "$CONF" ] && write_default_conf

# ─── mirror conf to sdcard on start ────────
load_conf
mirror_conf

log_msg "Sortify Xtended v1.0 started"

# ─── run migration check on start ──────────
migrate_original_sortify

# ─── boot-only sort ────────────────────────
if [ "${SCHEDULE:-always}" = "boot" ] && [ "${STOPPED:-false}" != "true" ]; then
    log_msg "[Boot] Running boot sort..."
    sh "$MODDIR/action.sh"
fi

# ─── background loop ───────────────────────
(
    while true; do
        load_conf
        mirror_conf

        if [ "$STOPPED" = "true" ]; then
            sleep 60
            continue
        fi

        if [ "$SCHEDULE" = "boot" ]; then
            sleep 60
            continue
        fi

        if [ "$PAUSED_UNTIL" != "0" ]; then
            if [ "$PAUSED_UNTIL" = "-1" ]; then
                log_msg "[Paused] Manual pause active"
                sleep "$INTERVAL"
                continue
            fi
            now=$(date '+%s')
            if [ "$now" -lt "$PAUSED_UNTIL" ]; then
                mins_left=$(( (PAUSED_UNTIL - now) / 60 ))
                log_msg "[Paused] ~${mins_left}m remaining"
                sleep "$INTERVAL"
                continue
            else
                log_msg "=== Resumed — pause expired ==="
                sed -i 's/^PAUSED_UNTIL=.*/PAUSED_UNTIL=0/' "$CONF"
                mirror_conf
            fi
        fi

        sh "$MODDIR/action.sh"

        sleep "$INTERVAL"
    done
) &
