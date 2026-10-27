# macOS Cloud Drive Mounting Guide (OpenList + rclone + FUSE-T)

A complete, production-ready guide and toolkit for mounting cloud storage providers (AliyunDrive, Baidu Netdisk, OneDrive, Google Drive, Quark, PikPak, SMB/WebDAV, and 40+ others) as a native local drive in macOS Finder using **OpenList** (the community-driven open-source continuation of AList), **rclone (`cmount`)**, and **FUSE-T**, complete with near real-time cross-device sync optimizations and automatic startup at login.

---

## 1. Overview & Architecture

```
[Cloud Storage Providers]
          │
          ▼
   [OpenList Server]       (Runs locally at http://localhost:5244, exposes WebDAV at /dav)
          │
          ▼
[Official rclone + FUSE-T] (Mounts http://localhost:5244/dav with VFS full read/write cache)
          │
          ▼
   [~/webdav (Finder)]     (Appears as a native "OpenList" volume in macOS Finder)
```

### Included Files in This Directory

| File | Description |
| :--- | :--- |
| `mount_dav.sh` | Automated startup & mounting shell script with race-condition protection, `.DS_Store` VFS cache cleanup, and Finder real-time sync optimizations |
| `README.md` | This comprehensive setup, optimization, and auto-start tutorial |

### Required Binaries & Official Download Links

Before proceeding, download the official **OpenList** and **rclone** executables for macOS:

1. **OpenList Official Releases**:
   - GitHub Releases: <https://github.com/OpenListTeam/OpenList/releases>
   - Official Documentation: <https://doc.oplist.org>
   - For Apple Silicon Macs (M1/M2/M3/M4), download `openlist-darwin-arm64.tar.gz` (for Intel Macs, download `openlist-darwin-amd64.tar.gz`) and extract the `openlist` binary.
2. **Official rclone with FUSE Mount Support**:
   - **All Versions Download Page**: <https://rclone.org/downloads/>
   - **Direct Download Link for Apple Silicon (M1/M2/M3/M4 ARM64)**: <https://downloads.rclone.org/rclone-current-osx-arm64.zip>
   - **Official One-Line Install Command** *(automatically detects system architecture and installs the official full version to `/usr/local/bin/rclone`)*:
     ```bash
     sudo -v ; curl https://rclone.org/install.sh | sudo bash
     ```

> [!IMPORTANT]
> **Why you MUST use the official `rclone` binary instead of Homebrew (`brew install rclone`):**
> The `rclone` package distributed via Homebrew disables FUSE mounting (`rclone mount`) due to macOS FUSE licensing restrictions in Homebrew core. If you run `rclone mount` using Homebrew's `rclone`, it will fail immediately.
>
> If you previously installed `rclone` via Homebrew, uninstall it first to avoid `PATH` conflicts:
> ```bash
> brew uninstall rclone
> ```
>
> The official `rclone` binary downloaded from the links/script above is compiled with `- go/tags: cmount`, which enables native mounting alongside `fuse-t`. You can verify this by running `./rclone version` and checking that `go/tags: cmount` is present.

---

## 2. Target File Paths & Directory Layout

To match the paths configured in `mount_dav.sh`, place the downloaded `openlist` and `rclone` binaries along with `mount_dav.sh` in `~/openlist` (`/Users/<your-username>/openlist`). The script will automatically create and mount your cloud storage to `~/webdav` (`/Users/<your-username>/webdav`).

### Expected Directory Structure

```text
~/
├── openlist/                   # Working directory for OpenList and rclone
│   ├── openlist                # OpenList executable binary
│   ├── rclone                  # Official rclone binary (with cmount support)
│   ├── mount_dav.sh            # Startup and mount script
│   ├── rclone.log              # Runtime log generated automatically by rclone
│   └── data/                   # Database & config folder generated automatically by OpenList
└── webdav/                     # Local mount point (appears as "OpenList" in Finder)
```

### Step-by-Step File Installation

Open **Terminal** (`Cmd + Space`, type `Terminal`), navigate to this tutorial folder, and run the following commands to set up `~/openlist`, download the binaries (example below for Apple Silicon `arm64`), and grant executable permissions:

```bash
# 1. Create the target ~/openlist directory and copy the mount script
mkdir -p ~/openlist
cp ./mount_dav.sh ~/openlist/

# 2. Download and extract OpenList (Apple Silicon arm64)
curl -L https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-darwin-arm64.tar.gz | tar -xz -C ~/openlist

# 3. Download and extract the official rclone binary (Apple Silicon arm64)
curl -L -o /tmp/rclone.zip https://downloads.rclone.org/rclone-current-osx-arm64.zip
unzip -j /tmp/rclone.zip "*/rclone" -d ~/openlist/
rm -f /tmp/rclone.zip

# 4. Ensure all binaries and the script have executable permissions
chmod +x ~/openlist/openlist ~/openlist/rclone ~/openlist/mount_dav.sh

# 5. Clear macOS Gatekeeper quarantine attributes (prevents "unidentified developer" popups)
xattr -cr ~/openlist
```

---

## 3. Step 1: Start and Configure OpenList

1. Navigate to your `~/openlist` directory and start the OpenList server:
   ```bash
   cd ~/openlist
   ./openlist start
   ```

2. Set a custom password for the OpenList `admin` account (replace `YOUR_PASSWORD` with your desired password):
   ```bash
   ./openlist admin set YOUR_PASSWORD
   ```
   *Terminal will output confirmation showing username `admin` and your new password.*

3. Configure your user permissions and cloud drives in the OpenList Web UI:
   - Open your browser and visit: **<http://localhost:5244>**
   - Sign in with username `admin` and the password you just set.
   - **Enable Full User & WebDAV Permissions (`403 Forbidden` Prevention)**:
     - Navigate to **Manage -> Users**, click **Edit** next to `admin`.
     - Check **all permission boxes**, especially **Make dir or upload**, **Rename**, **Move**, **Copy**, **Remove**, **WebDAV Read**, and **WebDAV Manage** (if `WebDAV Manage` or upload permissions are unchecked, writing files via `rclone` will fail with `403 Forbidden`).
     - Click **Save**.
   - **Add Cloud Storage & Tune for Real-Time Sync**:
     - Navigate to **Manage -> Storages -> Add** to connect your cloud storage accounts (e.g., AliyunDrive Open, Baidu Netdisk, OneDrive, Google Drive, Quark, etc.).
     - **Cache Expiration**: Set to **`1`** minute (default is `30` minutes) so changes made on other devices appear within ~1 minute without triggering cloud API rate limits.
     - **WebDAV Policy**: Set to **`native_proxy` (Local Proxy)** instead of `302 redirect` to ensure stable WebDAV file uploads.
     - *(Note)* Changes made in the OpenList Web UI (`Users` / `Storages`) take effect immediately upon clicking **Save**—no OpenList service restart is required.

> [!WARNING]
> **Multi-Device Warning: Do NOT Share a Single Rotating `Refresh Token` Across Multiple OpenList Instances**
> Cloud providers like AliyunDrive (`AliyunDrive Open`) use a **single-use rotating Refresh Token** mechanism: every time Machine A refreshes its `Access Token`, the provider issues a new `Refresh Token` and invalidates the old one, which immediately kicks Machine B offline with `401` / `403 Forbidden` errors.
> - **Recommended Multi-Mac Setup**: Connect the cloud drive on a single primary machine (or NAS), and have secondary machines mount the primary machine's WebDAV directly via `rclone` (or mount the primary OpenList instance using the **AList V3 / OpenList** storage driver).
> - **Independent Setup**: If two machines must connect independently, generate separate Refresh Tokens using **different OAuth client credentials (Client ID / Secret)** for each machine.

---

## 4. Step 2: Install FUSE-T and Configure rclone

### 4.1 Install `fuse-t` via Homebrew

**FUSE-T** is a modern, kext-less FUSE implementation for macOS. Unlike legacy macFUSE, FUSE-T runs entirely in user space via a local NFSv4 server without kernel extensions, meaning you do **not** need to reboot into Recovery Mode or lower macOS System Integrity Protection (SIP).

Run in Terminal:

```bash
brew tap macos-fuse-t/homebrew-cask
brew install fuse-t
```

*(If you already have the tap configured, simply running `brew install fuse-t` works as well.)*

### 4.2 Configure `rclone` (Takes Only 30 Seconds)

Run the `rclone` binary located in `~/openlist` to start the interactive configuration wizard:

```bash
~/openlist/rclone config
```

Follow the interactive prompts step by step:

1. **New remote**: Type `n` and press **Enter**.
2. **`name>`**: Type `openlist` and press **Enter**.
3. **`Storage>`**: Type `webdav` (or the corresponding number for WebDAV) and press **Enter**.
4. **`url>`**: Type `http://localhost:5244/dav` and press **Enter**.
5. **`vendor>`**: Select the number for `other` (or type `other`) and press **Enter**.
6. **`user>`**: Type your OpenList administrator username (`admin`) and press **Enter**.
7. **`pass>`**: Type `y` (*Yes, type in my own password*), press **Enter**, then enter your OpenList administrator password (and enter it a second time to confirm).
8. **Remaining Options (`bearer_token`, `Edit advanced config`, etc.)**: Simply press **Enter** through all remaining prompts to accept the default values.
9. **Save & Exit**: Press **Enter** to keep the `openlist` remote, then type `q` and press **Enter** to quit the wizard.

#### Verify Your `rclone` Connection

Test that `rclone` can list the directories from your local OpenList WebDAV server:

```bash
~/openlist/rclone lsd openlist:
```

If configured properly, this command will display the folders/storages you added in OpenList.

---

## 5. Step 3: Mount Your Cloud Drive Using `mount_dav.sh`

You can now run `mount_dav.sh` to start OpenList and mount your storage to `~/webdav`:

```bash
~/openlist/mount_dav.sh
```

### What `mount_dav.sh` Does Under the Hood

1. **Prioritizes Official `rclone` in `PATH`**: Prepends `$HOME/openlist` and Homebrew directories (`/opt/homebrew/bin:/usr/local/bin`) to `PATH` so that even non-interactive shells (like macOS Automator) always use the `cmount`-enabled `rclone` binary and locate `fuse-t`.
2. **Cleanly Unmounts & Terminates Old `rclone` Daemons**: Under FUSE-T, running `umount` alone detaches the volume but does **not** immediately stop the background `rclone --daemon` process. The script explicitly terminates any lingering `rclone mount openlist:` process (`pkill -TERM` and waits for exit) before touching the VFS cache so the old process cannot flush stale `.DS_Store` metadata back to disk on exit.
3. **Prevents `.DS_Store` Creation & Upload Loops (FUSE-T + rclone VFS Details)**:
   - **Why FUSE-T's `--noappledouble` isn't enough**: In FUSE-T (`go-nfsv4`), `--noappledouble` only blocks `._*` AppleDouble resource fork files—it does **not** block `.DS_Store`.
   - **Why `--exclude ".DS_Store"` must NOT be used**: In `rclone mount`, `--exclude` only filters remote directory listings (`PROPFIND`), not local VFS write-back cache uploads (`PUT`). Worse, hiding existing `.DS_Store` files from Finder tricks Finder into thinking no `.DS_Store` exists in the folder, causing Finder to repeatedly create and `PUT` new `.DS_Store` files every time you open a directory!
   - **How `mount_dav.sh` solves this**:
     1. Checks and enables `defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true` (and restarts `Finder` via `killall Finder` on first run so the setting takes effect immediately), instructing Finder never to write `.DS_Store` onto network/NFS-backed FUSE-T volumes.
     2. Purges any leftover `.DS_Store` and `._*` files from `~/Library/Caches/rclone/vfs/openlist` and `vfsMeta/openlist` *after* the old `rclone` daemon exits.

> [!TIP]
> **Best Practice When Browsing in macOS Finder:**
> Always open your mounted cloud drive by clicking the **`OpenList`** volume icon under **"Locations"** in the Finder sidebar (or on the Desktop), rather than navigating into the local `~/webdav` folder from your home directory. Accessing via the mounted volume ensures macOS strictly applies network volume rules (`DSDontWriteNetworkStores`) and never writes `.DS_Store` at the mount root.
4. **Starts OpenList Safely**: Runs `./openlist start --data "$HOME/openlist/data"` from `$HOME/openlist` so the database path is never lost regardless of where the script is called from.
5. **Prevents Startup Race Conditions**: Polls `http://localhost:5244` every second (up to 15 seconds) until OpenList is fully initialized before invoking `rclone mount`.
6. **Mounts with Real-Time Sync & Finder VFS Optimizations**: Mounts `openlist:` to `~/webdav` as a background daemon (`--daemon`) and displays it as **OpenList** in macOS Finder.

### `rclone mount` Parameters Explained

| Flag | Value | Purpose |
| :--- | :--- | :--- |
| `--vfs-cache-mode` | `full` | Enables full read/write disk caching. Required for macOS Finder operations (random read/write, file overwrites, media scrubbing). |
| `--vfs-cache-max-size` | `30G` | Caps local disk cache at 30 GB; automatically evicts oldest files using LRU when full. |
| `--vfs-cache-max-age` | `24h` | Removes cached files 24 hours after their last access. |
| `--vfs-read-chunk-size` | `64M` | Starts streaming downloads in 64 MB chunks. |
| `--vfs-read-chunk-size-limit` | `1G` | Doubles sequential read chunk size up to 1 GB for smooth 4K video playback and large file transfers. |
| `--buffer-size` | `32M` | Allocates 32 MB of RAM buffer per open file to smooth out network jitter. |
| `--dir-cache-time` | `15s` | Refreshes directory listings every 15 seconds for near real-time cross-device sync (WebDAV does not support server push notifications, and querying local `localhost:5244` takes `<1ms`). |
| `--vfs-write-back` | `3s` | Uploads modified files to the cloud 3 seconds after they are closed locally (default is 5 seconds). |
| `--no-modtime` | *(flag)* | **Required for FUSE-T**: FUSE-T's underlying macOS NFS client updates file `mtime` even when Finder merely reads or previews a file. Without `--no-modtime`, browsing files in Finder triggers false modification detections and re-uploads entire files. |
| `--no-checksum` | *(flag)* | Disables MD5/SHA1 checksum checks to avoid incompatibilities across cloud providers. |
| `--noappledouble` | *(flag)* | Supported by FUSE-T (`go-nfsv4`) to block AppleDouble (`._*`) resource fork file creation. |
| `--noapplexattr` | *(flag)* | Ignores macOS-specific `com.apple.*` extended attributes. |
| `--volname` | `"OpenList"` | Sets the volume name displayed in macOS Finder sidebar and Desktop. |
| `--vfs-cache-poll-interval` | `1m` | Checks local cache size every 1 minute to enforce the 30 GB quota. |
| `--log-file` | `~/openlist/rclone.log` | Writes operational logs to `~/openlist/rclone.log` for easy troubleshooting. |
| `--log-level` | `NOTICE` | Logs important events, warnings, and errors without bloating the log file. |
| `--daemon` | *(flag)* | Runs the mount process silently in the background. |

---

## 6. Step 4: Configure Auto-Start on macOS Boot (Automator + Login Items)

To have macOS automatically start OpenList and mount your cloud drives in the background every time you log in—without keeping a Terminal window open—combine a **macOS Automator Application** with **Login Items**.

### Part A: Create an Automator Application

1. Open **Automator** (`Cmd + Space`, type `Automator`, and press **Enter**).
2. Click **New Document**, select **Application** as the document type, and click **Choose**.
3. In the search bar at the top of the left sidebar, type **`Run Shell Script`**, then drag the **Run Shell Script** action into the right-hand workflow pane.
4. Configure the **Run Shell Script** action:
   - **Shell**: Select `/bin/bash`
   - **Pass input**: Select `to stdin` (default)
   - Replace the text inside the script box with:
     ```bash
     /bin/bash "$HOME/openlist/mount_dav.sh"
     ```
5. Click the **Run** button (top-right corner of Automator) once to verify the script runs cleanly and mounts the `OpenList` volume in Finder.
6. Press **`Cmd + S`** to save the application:
   - **Save As**: `MountOpenList.app`
   - **Where**: `/Applications` (or `~/openlist`)
   - **File Format**: `Application`

### Part B: Add the App to macOS Login Items

1. Open **System Settings** on your Mac.
2. Navigate to **General** -> **Login Items & Extensions** *(on older macOS versions: **System Preferences** -> **Users & Groups** -> **Login Items**)*.
3. Under the **Open at Login** section, click the **`+`** button.
4. Select **`MountOpenList.app`** from `/Applications` (or wherever you saved it) and click **Open**.

From now on, every time you log in to your Mac, `MountOpenList.app` will silently start OpenList, wait for port `5244` to come online, and mount your cloud storage to `~/webdav` (`OpenList` in Finder).

---

## 7. Daily Operations & Troubleshooting

### Check Mount Status
```bash
mount | grep webdav
# Or check mounted disk space:
df -h ~/webdav
```

### Manually Unmount and Stop `rclone`
```bash
umount ~/webdav || diskutil unmount force ~/webdav
pkill -TERM -f "rclone mount openlist:"
```

### Stop or Restart OpenList
```bash
cd ~/openlist
./openlist stop
./openlist restart
```

### Clear a Stuck Upload in the Local `rclone` VFS Cache
If a file fails to upload (e.g., `403 Forbidden` before permissions were granted) and keeps retrying in `rclone.log`:
```bash
# 1. Re-run mount_dav.sh (automatically stops rclone, clears .DS_Store, and remounts)
~/openlist/mount_dav.sh

# 2. Or manually delete a specific stuck file from the VFS cache while rclone is stopped:
rm -f "$HOME/Library/Caches/rclone/vfs/openlist/<path-to-stuck-file>"
rm -f "$HOME/Library/Caches/rclone/vfsMeta/openlist/<path-to-stuck-file>"
```

### View Logs for Troubleshooting
If the drive does not appear in Finder or files fail to open, check the `rclone` and `OpenList` logs:
```bash
# View rclone mount logs
tail -n 50 -f ~/openlist/rclone.log

# View OpenList server logs
tail -n 50 -f ~/openlist/data/log/log.log
```
