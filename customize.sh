#!/system/bin/sh
# ─────────────────────────────────────────────
# Sortify Xtended v1.0 - customize.sh
# Runs during flash via Magisk/KernelSU/APatch
# Author: Imnotshashwat
# ─────────────────────────────────────────────

MODDIR="$MODPATH"
CONF="$MODPATH/sortify.conf"
WEBROOT="$MODPATH/webroot"
OLD_CONF="/data/adb/modules/sortify/sortify.conf"

ui_print "─────────────────────────────────"
ui_print "  Sortify Xtended v1.0"
ui_print "  by Imnotshashwat"
ui_print "  Based on Sortify by xCaptaiN09"
ui_print "─────────────────────────────────"

# ─── check Android version ─────────────────
if [ "$API" -lt 26 ]; then
    ui_print "! Android 8.0+ required (API 26+)"
    abort "Unsupported Android version: API $API"
fi

ui_print "- Android API $API ✓"
ui_print "- Arch: $ARCH"

# ─── create webroot dir ────────────────────
ui_print "- Setting up webroot..."
mkdir -p "$WEBROOT"
chmod 755 "$WEBROOT"

# ─── write conf ────────────────────────────
ui_print "- Writing configuration..."

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
}

# helper — add key if missing from conf (upgrade safe)
add_if_missing() {
    key="$1"; val="$2"
    grep -q "^${key}=" "$CONF" 2>/dev/null || echo "${key}=${val}" >> "$CONF"
}

if [ -f "$CONF" ]; then
    # ── upgrade: existing Sortify Xtended conf ──
    ui_print "  ✔ Existing config found — merging new keys"
    # always reset stopped/paused on upgrade
    sed -i 's/^STOPPED=.*/STOPPED=false/' "$CONF"
    sed -i 's/^PAUSED_UNTIL=.*/PAUSED_UNTIL=0/' "$CONF"
    # add any new v1.0 keys
    add_if_missing "VERSION"           "1"
    add_if_missing "SCHEDULE"          "always"
    add_if_missing "SCHEDULE_FROM"     ""
    add_if_missing "SCHEDULE_TO"       ""
    add_if_missing "SORTING"           "false"
    add_if_missing "CAT_DOCUMENTS"     "true"
    add_if_missing "CAT_IMAGES"        "true"
    add_if_missing "CAT_AUDIO"         "true"
    add_if_missing "CAT_VIDEOS"        "true"
    add_if_missing "CAT_ARCHIVES"      "true"
    add_if_missing "CAT_APPS"          "true"
    add_if_missing "CAT_CODE"          "true"
    add_if_missing "CAT_DUPLICATES"    "true"
    add_if_missing "CAT_OTHERS"        "true"
    add_if_missing "EXT_DOCUMENTS"     ""
    add_if_missing "EXT_IMAGES"        ""
    add_if_missing "EXT_AUDIO"         ""
    add_if_missing "EXT_VIDEOS"        ""
    add_if_missing "EXT_ARCHIVES"      ""
    add_if_missing "EXT_APPS"          ""
    add_if_missing "EXT_CODE"          ""
    add_if_missing "EXCLUDE_EXTENSIONS" ""
    add_if_missing "EXCLUDE_FILES"     ""

elif [ -f "$OLD_CONF" ]; then
    # ── migration: old Sortify (v7.x) conf found ──
    ui_print "  ✔ Old Sortify config found — migrating settings"
    write_default_conf
    # migrate what we can from old conf
    old_interval=$(grep "^INTERVAL=" "$OLD_CONF" | cut -d= -f2)
    old_watch=$(grep "^WATCH_DIRS=" "$OLD_CONF" | cut -d= -f2)
    old_exclude=$(grep "^EXCLUDE=" "$OLD_CONF" | cut -d= -f2)
    [ -n "$old_interval" ] && sed -i "s/^INTERVAL=.*/INTERVAL=$old_interval/" "$CONF"
    [ -n "$old_watch" ]    && sed -i "s|^WATCH_DIRS=.*|WATCH_DIRS=$old_watch|" "$CONF"
    [ -n "$old_exclude" ]  && sed -i "s/^EXCLUDE_FILES=.*/EXCLUDE_FILES=$old_exclude/" "$CONF"
    # migrate old CUSTOM_FOLDER_* rules
    grep "^CUSTOM_FOLDER_" "$OLD_CONF" 2>/dev/null >> "$CONF"
    ui_print "  ✔ Settings migration complete"

else
    # ── fresh install ──
    ui_print "  ✔ Fresh install — writing defaults"
    write_default_conf
fi

# ─── copy conf to webroot immediately ──────
# so WebUI can read it on very first open
cp "$CONF" "$WEBROOT/sortify.conf" 2>/dev/null
chmod 666 "$WEBROOT/sortify.conf" 2>/dev/null
ui_print "  ✔ Config ready"

# ─── safe move helper (avoids overwriting duplicates) ───
safe_mv() {
    src_file="$1"
    dest_dir="$2"
    base_name=$(basename "$src_file")
    mkdir -p "$dest_dir"
    if [ -f "$dest_dir/$base_name" ]; then
        i=1
        case "$base_name" in
            *.*)
                name_prefix="${base_name%.*}"
                ext_suffix="${base_name##*.}"
                while [ -f "$dest_dir/${name_prefix}-$i.${ext_suffix}" ]; do
                    i=$((i + 1))
                done
                mv -f "$src_file" "$dest_dir/${name_prefix}-$i.${ext_suffix}"
                ;;
            *)
                while [ -f "$dest_dir/${base_name}-$i" ]; do
                    i=$((i + 1))
                done
                mv -f "$src_file" "$dest_dir/${base_name}-$i"
                ;;
        esac
    else
        mv -f "$src_file" "$dest_dir/$base_name"
    fi
}

# ─── legacy folder migration ───────────
# Migrate files from legacy Sortify folders into /sdcard/Download
DEST="/sdcard/Download"

for old_dir in "/sdcard/Sortify" "/sdcard/Download/Sortify"; do
    if [ -d "$old_dir" ]; then
        ui_print "─────────────────────────────────"
        ui_print "  ⚙ Legacy Sortify folder found:"
        ui_print "    $old_dir"
        ui_print "  Migrating files to Downloads..."

        # 1. Category folders
        for folder in Documents Images Videos Archives Apps Others Duplicates Code; do
            if [ -d "$old_dir/$folder" ]; then
                find "$old_dir/$folder" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
                    [ -n "$f" ] && safe_mv "$f" "$DEST/$folder"
                done
                rmdir "$old_dir/$folder" 2>/dev/null
            fi
        done

        # 2. Audio — detect music exts and route to Audio/Music, rest in Audio/
        if [ -d "$old_dir/Audio" ]; then
            MUSIC_EXTS="mp3 flac wav m4a ogg aac opus alac"
            find "$old_dir/Audio" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
                [ -z "$f" ] && continue
                ext=$(basename "$f" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
                is_music=false
                for me in $MUSIC_EXTS; do
                    if [ "$ext" = "$me" ]; then
                        is_music=true
                        break
                    fi
                done
                if [ "$is_music" = "true" ]; then
                    safe_mv "$f" "$DEST/Audio/Music"
                else
                    safe_mv "$f" "$DEST/Audio"
                fi
            done
            rmdir "$old_dir/Audio" 2>/dev/null
        fi

        # 3. Any leftover files directly in the root of old_dir
        find "$old_dir" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
            [ -n "$f" ] && safe_mv "$f" "$DEST"
        done

        # Remove old directory if empty
        rmdir "$old_dir" 2>/dev/null

        ui_print "  ✔ Migration from $old_dir complete"
        ui_print "─────────────────────────────────"
    fi
done

# ─── set permissions ───────────────────────
ui_print "- Setting permissions..."
set_perm_recursive "$MODPATH"         0 0 0755 0644
set_perm "$MODPATH/service.sh"        0 0 0755
set_perm "$MODPATH/action.sh"         0 0 0755
set_perm "$MODPATH/uninstall.sh"      0 0 0755
set_perm "$MODPATH/customize.sh"      0 0 0755
set_perm "$CONF"                      0 0 0644
set_perm "$WEBROOT/sortify.conf"      0 0 0644
ui_print "  ✔ Permissions applied"

ui_print "─────────────────────────────────"
ui_print "  Sortify Xtended installed!"
ui_print "  Open KernelSU / APatch / Magisk"
ui_print "  → Tap WebUI to configure"
ui_print "─────────────────────────────────"