# Sortify Xtended

<p align="center">
  <img src="banner.png" alt="Sortify Xtended Banner" width="100%" />
</p>

A background file organizer module for rooted Android devices running Magisk, KernelSU, or APatch. Sortify Xtended automatically moves files from your download folders into organized categories, with scheduling controls, custom folder rules, duplicate collision protection, migration from original Sortify, and an integrated WebUI.

Based on the original [Sortify](https://github.com/xCaptaiN09/Sortify) module by [xCaptaiN09](https://github.com/xCaptaiN09).

---

## Screenshots

<p align="center">
  <img src="screenshots/webui-dashboard.png" alt="WebUI Dashboard" width="30%" />
  &nbsp;
  <img src="screenshots/webui-overview.jpg" alt="WebUI Overview" width="30%" />
  &nbsp;
  <img src="screenshots/webui-settings.jpg" alt="WebUI Settings" width="30%" />
</p>

---

## Features

### Automated Sorting
- Runs automatically in the background at your chosen interval (default: every 6 hours).
- Supports multiple watch folders (default: `/sdcard/Download`).
- Safe file handling: skips incomplete downloads (`.crdownload`, `.part`, `.partial`), temporary files, system files, and files modified within the last 5 seconds to prevent moving active downloads.
- Skips critical firmware flash images (`boot.img`, `init_boot.img`, `vendor_boot.img`, `recovery.img`) to avoid breaking root patching tools and fastboot workflows.
- Safe duplicate handling: identifies duplicate files and moves them to `Duplicates/` with automatic collision renaming (e.g. `file-1.zip`, `file-2.zip`) so previous duplicates are never overwritten.

### Subcategory Routing
- **Screenshots:** image files matching screenshot naming patterns are routed into `Images/Screenshots`.
- **Music:** audio formats like MP3, FLAC, and WAV are placed in `Audio/Music`, while voice notes and other audio stay in `Audio`.
- **Root Modules:** ZIP archives containing root module files (`module.prop`, `action.sh`) are identified by inspecting archive headers and routed directly to `Archives/Modules` without extracting the file.

### Migration from Original Sortify
- Detects files sorted by the original Sortify module (in `/sdcard/Sortify` or `/sdcard/Download/Sortify`).
- Automatically moves them back to the download root with conflict renaming and cleans up the legacy folders so they can be re-sorted cleanly under Sortify Xtended.

### Multi-Layer Safety Net
- Watch folder validation blocks critical root paths and scoped storage folders (`/`, `/system`, `/data`, `/data/adb`, `/sdcard/Android`, `/sdcard/DCIM`).
- Safe directory cleanup: revert and uninstall routines only prune empty category directories and will never delete folders containing remaining files.

### Scheduling
- **Always:** sorts on a continuous timer.
- **Night:** runs only during night hours (midnight to 6:00 AM).
- **Custom window:** runs only within a specified time range (e.g. 02:00 to 05:00).
- **Boot only:** runs once at device boot and idles during normal use.

### Control and Recovery
- **Pause and resume:** temporarily pause the background service for 1 hour, 3 hours, 24 hours, or until manually resumed.
- **Undo last batch:** restores files moved during the most recent sorting run.
- **Full revert:** moves all sorted files back to the download root while safely handling name conflicts.
- **Clean uninstall:** running `uninstall.sh` restores files to their original directories before removing the module files.

---

## WebUI

The module includes a local dashboard accessible directly inside your root manager without needing an external web server or browser.

### Accessing the WebUI
1. Open **KernelSU**, **APatch**, or **Magisk**.
2. Navigate to the **Modules** tab.
3. Locate **Sortify Xtended** and tap the **WebUI / Action** button.

### WebUI Options
- Switch between dark and light themes.
- Toggle individual categories (Documents, Images, Audio, Videos, Archives, Apps, Code, Duplicates, Others).
- Define custom file extensions for each category.
- Create custom folder rules (e.g. route `.psd` files directly to `Photoshop/`).
- Set file and extension exclusion rules.
- View live sorting logs and cumulative statistics.

---

## Manual Trigger

To trigger a sort manually without opening the WebUI:
- Tap the **Action** button on the module card in Magisk or KernelSU.
- Or run the action script directly from a root terminal:
  ```bash
  su -c sh /data/adb/modules/sortify_xtended/action.sh --force
  ```

---

## Installation

1. Download the flashable `sortify_xtended.zip` from [Releases](../../releases).
2. Flash the zip in **Magisk**, **KernelSU**, or **APatch**.
3. Reboot your device.
4. Configure settings through the WebUI in your root manager.

---

## Credits

- Original Sortify module developed by **[xCaptaiN09](https://github.com/xCaptaiN09)** ([original repository](https://github.com/xCaptaiN09/Sortify)).
- Extended features, safety hardening, and WebUI by **[Imnotshashwat](https://github.com/Imnotshashwat)**.
