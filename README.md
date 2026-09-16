<p align="center">
  <img src="banner.png" alt="Sortify Xtended Banner" width="100%" />
</p>

# Sortify Xtended

<p align="left">
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Root-Magisk%20%7C%20KernelSU%20%7C%20APatch-orange" alt="Root Managers" />
  <img src="https://img.shields.io/badge/Version-v1.0-blue" alt="Version" />
  <img src="https://img.shields.io/badge/License-GPL--3.0-brightgreen" alt="License" />
</p>

A background file organizer module for rooted Android devices running Magisk, KernelSU, or APatch. Sortify Xtended automatically moves files from your download folders into organized categories, featuring scheduling windows, subcategory routing, duplicate collision protection, migration from original Sortify, and an integrated WebUI dashboard.

Based on the original [Sortify](https://github.com/xCaptaiN09/Sortify) module by [xCaptaiN09](https://github.com/xCaptaiN09).

---

## Screenshots

<p align="center">
  <img src="screenshots/webui-dashboard.png" alt="WebUI Dashboard" width="23%" />
  &nbsp;
  <img src="screenshots/webui-safety-toast.png" alt="WebUI Safety Net" width="23%" />
  &nbsp;
  <img src="screenshots/webui-overview.jpg" alt="WebUI Overview" width="23%" />
  &nbsp;
  <img src="screenshots/webui-settings.jpg" alt="WebUI Settings" width="23%" />
</p>

---

## Features

### Automated Sorting
- Runs automatically in the background at your chosen interval (default: every 5 minutes).
- Supports multiple watch folders (default: `/sdcard/Download`).
- Safe file handling: skips incomplete downloads (`.crdownload`, `.part`, `.partial`), temporary files, system files, and files modified within the last 5 seconds to prevent moving active downloads.
- Skips critical firmware flash images (`boot.img`, `init_boot.img`, `vendor_boot.img`, `recovery.img`) to avoid interrupting root patching tools and fastboot workflows.
- Safe duplicate handling: identifies duplicate files and moves them to `Duplicates/` with automatic collision renaming (e.g. `file-1.zip`, `file-2.zip`) so previous duplicates are never overwritten.

### Subcategory Routing
- **Screenshots:** image files matching screenshot naming patterns are routed into `Images/Screenshots`.
- **Music:** audio formats like MP3, FLAC, and WAV are placed in `Audio/Music`, while voice notes and other audio stay in `Audio`.
- **Root Modules:** ZIP archives containing root module files (`module.prop`, `action.sh`) are identified by inspecting archive headers and routed directly to `Archives/Modules` without extracting the file.

### Migration from Original Sortify
- **Installer Migration:** Flashing in Magisk or KernelSU automatically detects legacy Sortify installations, pulls old configuration settings, and migrates files from `/sdcard/Sortify` or `/sdcard/Download/Sortify` directly to your download directory.
- **Runtime Migration:** The background service and manual trigger also scan for legacy Sortify folders on boot and safely migrate any newly discovered legacy files.

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
   - The installer displays terminal feedback while setting up webroot, migrating older configs, and transferring legacy files.
3. Reboot your device.
4. Open your root manager and tap **Sortify Xtended → WebUI** to configure.

---

## Credits

- Original Sortify module developed by **[xCaptaiN09](https://github.com/xCaptaiN09)** ([original repository](https://github.com/xCaptaiN09/Sortify)).
- Extended features, safety hardening, and WebUI by **[Imnotshashwat](https://github.com/Imnotshashwat)**.