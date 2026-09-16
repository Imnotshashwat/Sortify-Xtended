#!/system/bin/sh
# ─────────────────────────────────────────────
# Sortify Xtended v1.0 - action.sh
# Author: Imnotshashwat
# ─────────────────────────────────────────────

MODDIR="/data/adb/modules/sortify_xtended"
CONF="$MODDIR/sortify.conf"
LOG="$MODDIR/sortify.log"
STATS="$MODDIR/sortify.stats"
HISTORY="$MODDIR/sortify.history"
WEBROOT="$MODDIR/webroot"
LOCK="/tmp/sortify_xtended.lock"

# ─── load config ───────────────────────────
if [ ! -f "$CONF" ]; then exit 1; fi
. "$CONF"

# ─── defaults ──────────────────────────────
INTERVAL="${INTERVAL:-300}"
SCHEDULE="${SCHEDULE:-always}"
SCHEDULE_FROM="${SCHEDULE_FROM:-}"
SCHEDULE_TO="${SCHEDULE_TO:-}"
WATCH_DIRS="${WATCH_DIRS:-/sdcard/Download}"
PAUSED_UNTIL="${PAUSED_UNTIL:-0}"
STOPPED="${STOPPED:-false}"
CAT_DOCUMENTS="${CAT_DOCUMENTS:-true}"
CAT_IMAGES="${CAT_IMAGES:-true}"
CAT_AUDIO="${CAT_AUDIO:-true}"
CAT_VIDEOS="${CAT_VIDEOS:-true}"
CAT_ARCHIVES="${CAT_ARCHIVES:-true}"
CAT_APPS="${CAT_APPS:-true}"
CAT_CODE="${CAT_CODE:-true}"
CAT_DUPLICATES="${CAT_DUPLICATES:-true}"
CAT_OTHERS="${CAT_OTHERS:-true}"
EXT_DOCUMENTS="${EXT_DOCUMENTS:-}"
EXT_IMAGES="${EXT_IMAGES:-}"
EXT_AUDIO="${EXT_AUDIO:-}"
EXT_VIDEOS="${EXT_VIDEOS:-}"
EXT_ARCHIVES="${EXT_ARCHIVES:-}"
EXT_APPS="${EXT_APPS:-}"
EXT_CODE="${EXT_CODE:-}"
EXCLUDE_EXTENSIONS="${EXCLUDE_EXTENSIONS:-}"
EXCLUDE_FILES="${EXCLUDE_FILES:-}"

# ─── stopped check ─────────────────────────
FORCE=false
[ "$1" = "--force" ] && FORCE=true
[ "$STOPPED" = "true" ] && [ "$FORCE" = "false" ] && exit 0

# ─── pause check ───────────────────────────
if [ "$PAUSED_UNTIL" != "0" ] && [ "$FORCE" = "false" ]; then
    [ "$PAUSED_UNTIL" = "-1" ] && exit 0
    now=$(date '+%s')
    if [ "$now" -lt "$PAUSED_UNTIL" ]; then
        exit 0
    else
        sed -i 's/^PAUSED_UNTIL=.*/PAUSED_UNTIL=0/' "$CONF"
    fi
fi

# ─── lock ──────────────────────────────────
if [ -f "$LOCK" ]; then
    lock_age=$(( $(date '+%s') - $(date -r "$LOCK" '+%s' 2>/dev/null || echo 0) ))
    [ "$lock_age" -gt 600 ] && rm -f "$LOCK" || exit 0
fi
touch "$LOCK"
trap 'rm -f "$LOCK" "$SORTED_FILE" "$DUPE_FILE"' EXIT

# ─── schedule check ────────────────────────
if [ "$FORCE" = "false" ]; then
case "$SCHEDULE" in
    night)
        t=$(date '+%k%M' | tr -d ' ')
        [ "$t" -gt 600 ] && [ "$t" -lt 2400 ] && { rm -f "$LOCK"; exit 0; }
        ;;
    custom)
        if [ -n "$SCHEDULE_FROM" ] && [ -n "$SCHEDULE_TO" ]; then
            current_time=$(date '+%H:%M')
            sf="$SCHEDULE_FROM"; st="$SCHEDULE_TO"
            if [ "$sf" \< "$st" ]; then
                { [ "$current_time" \< "$sf" ] || [ "$current_time" \> "$st" ]; } && { rm -f "$LOCK"; exit 0; }
            else
                { [ "$current_time" \< "$sf" ] && [ "$current_time" \> "$st" ]; } && { rm -f "$LOCK"; exit 0; }
            fi
        fi
        ;;
esac
fi

# ─── default extensions ────────────────────
DEF_DOCUMENTS="pdf doc docx xls xlsx ppt pptx txt csv odt rtf epub"
DEF_IMAGES="jpg jpeg png heic webp svg dng raw gif bmp tiff avif"
DEF_MUSIC="mp3 flac wav m4a"
DEF_AUDIO="aac opus ogg wma aiff ape amr 3ga"
DEF_VIDEOS="mp4 mkv mov webm avi flv 3gp ts m4v wmv mpg mpeg"
DEF_ARCHIVES="zip rar 7z tar gz xz iso bz2 zst"
DEF_APPS="apk xapk apks apkm"
DEF_CODE="js ts py sh html css json xml java kt cpp c php rb go sql"

# merge defaults + custom
DOCUMENTS="$DEF_DOCUMENTS $EXT_DOCUMENTS"
IMAGES="$DEF_IMAGES $EXT_IMAGES"
MUSIC="$DEF_MUSIC"
AUDIO="$DEF_AUDIO $EXT_AUDIO"
VIDEOS="$DEF_VIDEOS $EXT_VIDEOS"
ARCHIVES="$DEF_ARCHIVES $EXT_ARCHIVES"
APPS="$DEF_APPS $EXT_APPS"
CODE="$DEF_CODE $EXT_CODE"

# ─── subshell-safe counters ────────────────
SORTED_FILE="/tmp/sortify_xtended_sorted_$$"
DUPE_FILE="/tmp/sortify_xtended_dupes_$$"
echo 0 > "$SORTED_FILE"
echo 0 > "$DUPE_FILE"

# ─── logging ───────────────────────────────
FIRST_WATCH=$(echo "$WATCH_DIRS" | cut -d',' -f1 | xargs)
SDCARD_LOG_DIR="${FIRST_WATCH:-/sdcard/Download}/Sortify"
SDCARD_LOG="$SDCARD_LOG_DIR/sortify.log"

log_msg() {
    [ ! -f "$LOG" ] && touch "$LOG" && chmod 666 "$LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

flush_log() {
    cutoff=$(date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-24H '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
    if [ -n "$cutoff" ]; then
        awk -v cut="[$cutoff]" '{
            if (/===|---|\[Pause\]|\[Resume\]|\[Info\]|\[Settings\]/) { print; next }
            if ($0 > cut) { print }
        }' "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
    fi
    tail -n 5000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    mkdir -p "$SDCARD_LOG_DIR" 2>/dev/null
    cp "$LOG" "$SDCARD_LOG" 2>/dev/null
    chmod 666 "$SDCARD_LOG" 2>/dev/null
    cp "$CONF" "$SDCARD_LOG_DIR/sortify.conf" 2>/dev/null
    chmod 666 "$SDCARD_LOG_DIR/sortify.conf" 2>/dev/null
}

# ─── history ───────────────────────────────
record_history() {
    echo "$(date '+%s')|$1|$2" >> "$HISTORY"
    chmod 666 "$HISTORY"
}

flush_history() {
    cutoff_ts=$(date -d '24 hours ago' '+%s' 2>/dev/null || date -v-24H '+%s' 2>/dev/null)
    if [ -n "$cutoff_ts" ]; then
        awk -F'|' -v cut="$cutoff_ts" '$1 > cut' "$HISTORY" > "$HISTORY.tmp" 2>/dev/null && mv "$HISTORY.tmp" "$HISTORY"
    fi
    tail -n 5000 "$HISTORY" > "$HISTORY.tmp" && mv "$HISTORY.tmp" "$HISTORY"
}

# ─── stats ─────────────────────────────────
update_stats() {
    SORTED_COUNT=$(cat "$SORTED_FILE" 2>/dev/null || echo 0)
    DUPE_COUNT=$(cat "$DUPE_FILE" 2>/dev/null || echo 0)
    total_sorted=0; total_dupes=0
    if [ -f "$STATS" ]; then
        total_sorted=$(grep "^TOTAL_SORTED=" "$STATS" | cut -d= -f2)
        total_dupes=$(grep "^TOTAL_DUPES=" "$STATS" | cut -d= -f2)
        total_sorted=${total_sorted:-0}
        total_dupes=${total_dupes:-0}
    fi
    total_sorted=$((total_sorted + SORTED_COUNT))
    total_dupes=$((total_dupes + DUPE_COUNT))
    printf "TOTAL_SORTED=%d\nTOTAL_DUPES=%d\nLAST_RUN=%s\nLAST_RUN_SORTED=%d\nLAST_RUN_DUPES=%d\n" \
        "$total_sorted" "$total_dupes" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$SORTED_COUNT" "$DUPE_COUNT" > "$STATS"
    chmod 666 "$STATS"
    cp "$STATS" "$WEBROOT/sortify.stats" 2>/dev/null
    chmod 666 "$WEBROOT/sortify.stats" 2>/dev/null
}

# ─── helpers ───────────────────────────────
get_ext() {
    fname=$(basename "$1")
    echo "${fname##*.}" | tr '[:upper:]' '[:lower:]'
}

has_ext() {
    needle="$1"; haystack="$2"
    for e in $haystack; do [ "$needle" = "$e" ] && return 0; done
    return 1
}

is_excluded() {
    fname=$(basename "$1")
    ext=$(get_ext "$1")
    for ex in $EXCLUDE_EXTENSIONS; do [ "$ext" = "$ex" ] && return 0; done
    for ef in $EXCLUDE_FILES; do
        [ "$fname" = "$ef" ] && return 0
        [ "${fname%.*}" = "$ef" ] && return 0
    done
    return 1
}

is_screenshot() {
    fname=$(basename "$1")
    case "$fname" in
        Screenshot_*|screenshot_*|Screen_Shot_*|SCREENSHOT_*|IMG_SNAP*|\
        "Screenshot "*|"screenshot "*)
            return 0 ;;
    esac
    return 1
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

# ─── move file (with safe duplicate handling) ──
do_move() {
    src="$1"; dest_dir="$2"; label="$3"
    fname=$(basename "$src")
    mkdir -p "$dest_dir"

    if [ -e "$dest_dir/$fname" ]; then
        if [ "$CAT_DUPLICATES" = "true" ]; then
            watch_base="$4"
            dupes_dir="$watch_base/Duplicates"
            mkdir -p "$dupes_dir"
            target="$dupes_dir/$fname"
            if [ -e "$target" ]; then
                i=1
                case "$fname" in
                    *.*)
                        base_n="${fname%.*}"
                        ext_n="${fname##*.}"
                        while [ -e "$dupes_dir/${base_n}-$i.${ext_n}" ]; do
                            i=$((i + 1))
                        done
                        target="$dupes_dir/${base_n}-$i.${ext_n}"
                        ;;
                    *)
                        while [ -e "$dupes_dir/${fname}-$i" ]; do
                            i=$((i + 1))
                        done
                        target="$dupes_dir/${fname}-$i"
                        ;;
                esac
            fi
            log_msg "[Duplicate] $fname → Duplicates/$(basename "$target")"
            record_history "$src" "$target"
            mv -f "$src" "$target"
            echo $(( $(cat "$DUPE_FILE") + 1 )) > "$DUPE_FILE"
        else
            log_msg "[SKIP] $fname — duplicate (Duplicates disabled)"
        fi
    else
        log_msg "[Sorted] $fname → $label"
        record_history "$src" "$dest_dir/$fname"
        mv -f "$src" "$dest_dir/"
        echo $(( $(cat "$SORTED_FILE") + 1 )) > "$SORTED_FILE"
    fi
}

# ─── module zip detection (no unzip needed) ──
is_module_zip() {
    grep -qaE "module\.prop|action\.sh|service\.sh|META-INF/com/google/android" "$1" 2>/dev/null
}

# ─── custom folder rules ───────────────────
sort_custom() {
    src="$1"; base="$2"
    ext=$(get_ext "$src")
    while IFS='=' read -r key val; do
        case "$key" in
            CUSTOM_FOLDER_*)
                folder="${key#CUSTOM_FOLDER_}"
                old_ifs="$IFS"
                IFS=' '
                for ce in $val; do
                    if [ "$ext" = "$ce" ]; then
                        IFS="$old_ifs"
                        do_move "$src" "$base/$folder" "Custom/$folder" "$base"
                        return 0
                    fi
                done
                IFS="$old_ifs"
                ;;
        esac
    done < "$CONF"
    return 1
}

# ─── sort single file ──────────────────────
sort_file() {
    src="$1"; base="$2"
    [ -f "$src" ] || return
    fname=$(basename "$src")
    # skip hidden files
    case "$fname" in .*) return ;; esac
    # skip incomplete downloads + temp + recycle/trash + firmware images
    case "$fname" in
        *.crdownload|*.part|*.download|*.partial|*.!ut|*.aria2)
            log_msg "[Skip] Incomplete download: $fname"; return ;;
        *.tmp|*.temp|*.swp|*.swo|*~)
            log_msg "[Skip] Temp file: $fname"; return ;;
        *.trashed|*.deleted|*.recycle)
            log_msg "[Skip] Trash: $fname"; return ;;
        .Trashes|.Trash-*|Thumbs.db|desktop.ini|.nomedia)
            log_msg "[Skip] System: $fname"; return ;;
        sortify.log|sortify.stats|sortify.history|sortify.conf)
            log_msg "[Skip] Sortify file: $fname"; return ;;
        boot.img|init_boot.img|vendor_boot.img|recovery.img|dtbo.img)
            log_msg "[Skip] Firmware image: $fname"; return ;;
    esac
    # skip files inside recycle/trash folders
    case "$src" in
        */.Trash*|*/.recycle*|*/.Recycle*|*/RECYCLE.BIN*|*/.trashed*)
            log_msg "[Skip] Inside trash folder: $fname"; return ;;
    esac
    # skip files modified less than 5 seconds ago (still being written)
    file_mtime=$(date -r "$src" '+%s' 2>/dev/null || echo 0)
    now_ts=$(date '+%s')
    age=$(( now_ts - file_mtime ))
    if [ "$age" -lt 5 ]; then
        log_msg "[Skip] Too recent: $(basename "$src")"; return
    fi
    is_excluded "$src" && { log_msg "[Excluded] $(basename "$src")"; return; }

    ext=$(get_ext "$src")

    # 1. Custom folder rules
    sort_custom "$src" "$base" && return

    # 2. Documents
    if [ "$CAT_DOCUMENTS" = "true" ] && has_ext "$ext" "$DOCUMENTS"; then
        do_move "$src" "$base/Documents" "Documents" "$base"; return
    fi

    # 3. Images
    if [ "$CAT_IMAGES" = "true" ] && has_ext "$ext" "$IMAGES"; then
        if is_screenshot "$src"; then
            do_move "$src" "$base/Images/Screenshots" "Images/Screenshots" "$base"
        else
            do_move "$src" "$base/Images" "Images" "$base"
        fi
        return
    fi

    # 4. Audio
    if [ "$CAT_AUDIO" = "true" ]; then
        if has_ext "$ext" "$MUSIC"; then
            do_move "$src" "$base/Audio/Music" "Audio/Music" "$base"; return
        fi
        if has_ext "$ext" "$AUDIO"; then
            do_move "$src" "$base/Audio" "Audio" "$base"; return
        fi
    fi

    # 5. Videos
    if [ "$CAT_VIDEOS" = "true" ] && has_ext "$ext" "$VIDEOS"; then
        do_move "$src" "$base/Videos" "Videos" "$base"
        return
    fi

    # 6. Archives
    if [ "$CAT_ARCHIVES" = "true" ] && has_ext "$ext" "$ARCHIVES"; then
        if [ "$ext" = "zip" ] && is_module_zip "$src"; then
            do_move "$src" "$base/Archives/Modules" "Archives/Modules" "$base"
        else
            do_move "$src" "$base/Archives" "Archives" "$base"
        fi
        return
    fi

    # 7. Apps
    if [ "$CAT_APPS" = "true" ] && has_ext "$ext" "$APPS"; then
        do_move "$src" "$base/Apps" "Apps" "$base"; return
    fi

    # 8. Code
    if [ "$CAT_CODE" = "true" ] && has_ext "$ext" "$CODE"; then
        do_move "$src" "$base/Code" "Code" "$base"; return
    fi

    # 9. Others
    if [ "$CAT_OTHERS" = "true" ]; then
        known=false
        has_ext "$ext" "$DOCUMENTS" && known=true
        has_ext "$ext" "$IMAGES" && known=true
        has_ext "$ext" "$MUSIC" && known=true
        has_ext "$ext" "$AUDIO" && known=true
        has_ext "$ext" "$VIDEOS" && known=true
        has_ext "$ext" "$ARCHIVES" && known=true
        has_ext "$ext" "$APPS" && known=true
        has_ext "$ext" "$CODE" && known=true
        if [ "$known" = "false" ]; then
            do_move "$src" "$base/Others" "Others" "$base"
        else
            log_msg "[Skip] $fname — category disabled"
        fi
    fi
}

# ─── sort watch directory ──────────────────
sort_dir() {
    base="$1"
    log_msg "=== Sort started ==="
    log_msg "--- Sorting: $base ---"
    find "$base" -maxdepth 1 -type f 2>/dev/null | while read -r file; do
        sort_file "$file" "$base"
    done
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

# ─── main ──────────────────────────────────
migrate_original_sortify

IFS=','
for dir in $WATCH_DIRS; do
    IFS=' '
    dir=$(echo "$dir" | xargs)
    if [ -d "$dir" ]; then
        if is_valid_watch_dir "$dir"; then
            sort_dir "$dir"
        else
            log_msg "[BLOCKED] Protected or invalid directory skipped: $dir"
        fi
    else
        log_msg "[WARN] Not found: $dir"
    fi
    IFS=','
done
IFS=' '

update_stats

SORTED_COUNT=$(cat "$SORTED_FILE" 2>/dev/null || echo 0)
DUPE_COUNT=$(cat "$DUPE_FILE" 2>/dev/null || echo 0)
log_msg "--- Done. Sorted: $SORTED_COUNT | Dupes: $DUPE_COUNT ---"

# ─── flush logs/history once at end ───────
flush_log
flush_history

# ─── action button output ──────────────────
TOTAL_SORTED=$(grep "^TOTAL_SORTED=" "$STATS" 2>/dev/null | cut -d= -f2 || echo 0)
TOTAL_DUPES=$(grep "^TOTAL_DUPES=" "$STATS" 2>/dev/null | cut -d= -f2 || echo 0)
LAST_RUN=$(grep "^LAST_RUN=" "$STATS" 2>/dev/null | cut -d= -f2- || echo "—")

echo ""
echo "📦 SORTED=$SORTED_COUNT"
echo "🔁 DUPES=$DUPE_COUNT"
echo "🕐 LAST_RUN=$LAST_RUN"
echo "📊 ALL_SORTED=$TOTAL_SORTED"
echo "🔁 ALL_DUPES=$TOTAL_DUPES"

# ─── signal WebUI sort is complete ─────────
sed -i 's/^SORTING=.*/SORTING=false/' "$CONF" 2>/dev/null
FIRST_WATCH_DIR=$(echo "$WATCH_DIRS" | cut -d',' -f1 | xargs)
SDCARD_CONF_DIR="${FIRST_WATCH_DIR:-/sdcard/Download}/Sortify"
mkdir -p "$SDCARD_CONF_DIR" 2>/dev/null
cp "$CONF" "$SDCARD_CONF_DIR/sortify.conf" 2>/dev/null
chmod 666 "$SDCARD_CONF_DIR/sortify.conf" 2>/dev/null
