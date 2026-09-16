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

# ─── device info detection ─────────────────
BRAND=$(getprop ro.product.brand 2>/dev/null)
[ -z "$BRAND" ] && BRAND=$(getprop ro.product.manufacturer 2>/dev/null)
[ -z "$BRAND" ] && BRAND="Unknown"

MODEL=$(getprop ro.product.model 2>/dev/null)
[ -z "$MODEL" ] && MODEL="Unknown"

ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null)
[ -z "$ANDROID_VER" ] && ANDROID_VER="$API"

DEVICE_ARCH=$(getprop ro.product.cpu.abi 2>/dev/null)
[ -z "$DEVICE_ARCH" ] && DEVICE_ARCH="$ARCH"

KERNEL_VER=$(uname -r 2>/dev/null)
[ -z "$KERNEL_VER" ] && KERNEL_VER="Unknown"

if [ "$KSU" = "true" ]; then
    if [ -n "$KSU_VER_CODE" ]; then
        ROOT_MGR="KernelSU ($KSU_VER_CODE)"
    elif [ -n "$KSU_VER" ]; then
        ROOT_MGR="KernelSU ($KSU_VER)"
    else
        ROOT_MGR="KernelSU"
    fi
elif [ "$APATCH" = "true" ]; then
    if [ -n "$APATCH_VER_CODE" ]; then
        ROOT_MGR="APatch ($APATCH_VER_CODE)"
    elif [ -n "$APATCH_VER" ]; then
        ROOT_MGR="APatch ($APATCH_VER)"
    else
        ROOT_MGR="APatch"
    fi
elif [ -n "$MAGISK_VER" ]; then
    if [ -n "$MAGISK_VER_CODE" ]; then
        ROOT_MGR="Magisk ($MAGISK_VER, $MAGISK_VER_CODE)"
    else
        ROOT_MGR="Magisk ($MAGISK_VER)"
    fi
else
    ROOT_MGR="Root (Unknown)"
fi

CURR_TIME=$(date "+%d, %b - %H:%M %Z" 2>/dev/null)
[ -z "$CURR_TIME" ] && CURR_TIME=$(date 2>/dev/null)

ui_print "Welcome to Sortify Xtended installation wizard!"
ui_print ""
ui_print "------------------------------------------------\\"
ui_print "                                                \\"
ui_print "- ⚙️  Module Version: v1.0"
ui_print "- 📱 Device Brand: $BRAND"
ui_print "- 📱 Device Model: $MODEL"
ui_print "- 🤖 Android Version: $ANDROID_VER"
ui_print "- 🏹 Device Arch: $DEVICE_ARCH"
ui_print "- 🛠️  Kernel version: $KERNEL_VER"
ui_print "- 🔒 Root Manager: $ROOT_MGR"
ui_print "- ⏳ Current Time: $CURR_TIME"
ui_print "                                                /"
ui_print "------------------------------------------------/"
ui_print ""

# ─── check Android version ─────────────────
if [ "$API" -lt 26 ]; then
    ui_print "! Android 8.0+ required (API 26+)"
    abort "Unsupported Android version: API $API"
fi

# ─── create webroot dir ────────────────────
ui_print "[*] Preparing Sortify Xtended environment"
ui_print "[*] Setting up webroot"
mkdir -p "$WEBROOT"
chmod 755 "$WEBROOT"

# ─── write conf ────────────────────────────
ui_print "[*] Writing configuration"

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
    ui_print "    ✔ Existing configuration merged"
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
    ui_print "    ✔ Settings imported from previous configuration"
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

else
    # ── fresh install ──
    ui_print "    ✔ Default configuration applied"
    write_default_conf
fi

# Copy conf to webroot immediately so WebUI can read on first launch
cp "$CONF" "$WEBROOT/sortify.conf" 2>/dev/null
chmod 666 "$WEBROOT/sortify.conf" 2>/dev/null

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

# ─── legacy migration & cleanup ───
DEST="/sdcard/Download"
has_migrated=false

start_legacy_box() {
    if [ "$has_migrated" != "true" ]; then
        has_migrated=true
        ui_print "[*] Migrating legacy Sortify data"
    fi
}

# 1. Check true legacy Sortify directory (/sdcard/Sortify)
if [ -d "/sdcard/Sortify" ]; then
    if [ -n "$(find "/sdcard/Sortify" -type f 2>/dev/null)" ]; then
        start_legacy_box
        for folder in Documents Images Videos Archives Apps Others Duplicates Code; do
            if [ -d "/sdcard/Sortify/$folder" ]; then
                find "/sdcard/Sortify/$folder" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
                    [ -n "$f" ] && safe_mv "$f" "$DEST/$folder"
                done
                rmdir "/sdcard/Sortify/$folder" 2>/dev/null
            fi
        done

        if [ -d "/sdcard/Sortify/Audio" ]; then
            MUSIC_EXTS="mp3 flac wav m4a ogg aac opus alac"
            find "/sdcard/Sortify/Audio" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
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
            rmdir "/sdcard/Sortify/Audio" 2>/dev/null
        fi

        find "/sdcard/Sortify" -maxdepth 1 -type f ! -name "sortify.log" ! -name "sortify.conf" 2>/dev/null | while read -r f; do
            [ -n "$f" ] && safe_mv "$f" "$DEST"
        done

        rm -rf "/sdcard/Sortify" 2>/dev/null
        ui_print "    • Migrated /sdcard/Sortify"
    else
        rm -rf "/sdcard/Sortify" 2>/dev/null
    fi
fi

# 2. Check if legacy /sdcard/Download/Sortify has category folders (ignore if just log/conf)
if [ -d "/sdcard/Download/Sortify" ]; then
    has_cat=false
    for folder in Documents Images Videos Archives Apps Others Duplicates Code Audio; do
        if [ -d "/sdcard/Download/Sortify/$folder" ]; then
            has_cat=true
            break
        fi
    done
    if [ "$has_cat" = "true" ]; then
        start_legacy_box
        for folder in Documents Images Videos Archives Apps Others Duplicates Code; do
            if [ -d "/sdcard/Download/Sortify/$folder" ]; then
                find "/sdcard/Download/Sortify/$folder" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
                    [ -n "$f" ] && safe_mv "$f" "$DEST/$folder"
                done
                rmdir "/sdcard/Download/Sortify/$folder" 2>/dev/null
            fi
        done
        if [ -d "/sdcard/Download/Sortify/Audio" ]; then
            MUSIC_EXTS="mp3 flac wav m4a ogg aac opus alac"
            find "/sdcard/Download/Sortify/Audio" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
                [ -z "$f" ] && continue
                ext=$(basename "$f" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
                is_music=false
                for me in $MUSIC_EXTS; do [ "$ext" = "$me" ] && is_music=true && break; done
                if [ "$is_music" = "true" ]; then
                    safe_mv "$f" "$DEST/Audio/Music"
                else
                    safe_mv "$f" "$DEST/Audio"
                fi
            done
            rmdir "/sdcard/Download/Sortify/Audio" 2>/dev/null
        fi
        ui_print "    • Migrated /sdcard/Download/Sortify"
    fi
fi

# 3. Cleanly remove old original module if installed
if [ -d "/data/adb/modules/sortify" ]; then
    start_legacy_box
    touch "/data/adb/modules/sortify/remove" 2>/dev/null
    rm -rf "/data/adb/modules/sortify" 2>/dev/null
    ui_print "    • Replaced legacy Sortify module"
fi

if [ "$has_migrated" = "true" ]; then
    ui_print "    ✔ Migration complete"
fi

# ─── set permissions ───────────────────────
ui_print "[*] Applying permissions"
set_perm_recursive "$MODPATH"         0 0 0755 0644
set_perm "$MODPATH/service.sh"        0 0 0755
set_perm "$MODPATH/action.sh"         0 0 0755
set_perm "$MODPATH/uninstall.sh"      0 0 0755
set_perm "$MODPATH/customize.sh"      0 0 0755
set_perm "$CONF"                      0 0 0644
set_perm "$WEBROOT/sortify.conf"      0 0 0644

ui_print "[*] Sortify Xtended installed successfully!"
ui_print "    Open KernelSU / APatch / Magisk"
ui_print "    → Tap WebUI to configure"