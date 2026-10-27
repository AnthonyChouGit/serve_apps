# macOS Cloud Drive Mounting Guide (OpenList + rclone + FUSE-T)

A complete, production-ready guide and toolkit for mounting cloud storage providers (AliyunDrive, Baidu Netdisk, OneDrive, Google Drive, Quark, PikPak, SMB/WebDAV, and 40+ others) as a native local drive in macOS Finder using **OpenList** (the community-driven open-source continuation of AList), **rclone (`cmount`)**, and **FUSE-T**, complete with automatic startup at login.

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
| `mount_openlist.sh` | Automated startup & mounting shell script with race-condition protection and Finder VFS optimizations |
| `README.md` | This comprehensive setup and auto-start tutorial |

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

To match the paths configured in `mount_openlist.sh`, place the downloaded `openlist` and `rclone` binaries along with `mount_openlist.sh` in `~/openlist` (`/Users/<your-username>/openlist`). The script will automatically create and mount your cloud storage to `~/webdav` (`/Users/<your-username>/webdav`).

### Expected Directory Structure

```text
~/
├── openlist/                   # Working directory for OpenList and rclone
│   ├── openlist                # OpenList executable binary
│   ├── rclone                  # Official rclone binary (with cmount support)
│   ├── mount_openlist.sh       # Startup and mount script
│   ├── rclone.log              # Runtime log generated automatically by rclone
│   └── data/                   # Database & config folder generated automatically by OpenList
└── webdav/                     # Local mount point (appears as "OpenList" in Finder)
```

### Step-by-Step File Installation

Open **Terminal** (`Cmd + Space`, type `Terminal`), navigate to this tutorial folder, and run the following commands to set up `~/openlist`, download the binaries (example below for Apple Silicon `arm64`), and grant executable permissions:

```bash
# 1. Create the target ~/openlist directory and copy the mount script
mkdir -p ~/openlist
cp ./mount_openlist.sh ~/openlist/

# 2. Download and extract OpenList (Apple Silicon arm64)
curl -L https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-darwin-arm64.tar.gz | tar -xz -C ~/openlist

# 3. Download and extract the official rclone binary (Apple Silicon arm64)
curl -L -o /tmp/rclone.zip https://downloads.rclone.org/rclone-current-osx-arm64.zip
unzip -j /tmp/rclone.zip "*/rclone" -d ~/openlist/
rm -f /tmp/rclone.zip

# 4. Ensure all binaries and the script have executable permissions
chmod +x ~/openlist/openlist ~/openlist/rclone ~/openlist/mount_openlist.sh

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

3. Configure your cloud drives in the OpenList Web UI:
   - Open your browser and visit: **<http://localhost:5244>**
   - Sign in with username `admin` and the password you just set.
   - Click **Manage** at the bottom of the page -> **Storages** -> **Add** to connect your cloud storage accounts (e.g., AliyunDrive Open, Baidu Netdisk, OneDrive, Google Drive, Quark, etc.).
   - *(Tip)* Under **Manage -> Users**, ensure the `admin` user has **WebDAV Read** and **WebDAV Manage** permissions enabled (enabled by default).

---

## 4. Step 2: Install FUSE-T and Configure rclone

### 4.1 Install `fuse-t` via Homebrew

**FUSE-T** is a modern, kext-less FUSE implementation for macOS. Unlike legacy macFUSE, FUSE-T runs entirely in user space without kernel extensions, meaning you do **not** need to reboot into Recovery Mode or lower macOS System Integrity Protection (SIP).

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

## 5. Step 3: Mount Your Cloud Drive Using `mount_openlist.sh`

You can now run `mount_openlist.sh` to start OpenList and mount your storage to `~/webdav`:

```bash
~/openlist/mount_openlist.sh
```

### What `mount_openlist.sh` Does Under the Hood

1. **Prioritizes Official `rclone` in `PATH`**: Prepends `$HOME/openlist` and Homebrew directories (`/opt/homebrew/bin:/usr/local/bin`) to `PATH` so that even non-interactive shells (like macOS Automator) always use the `cmount`-enabled `rclone` binary and locate `fuse-t`.
2. **Cleans Up Stale Mounts**: Checks if `~/webdav` is stuck from an unexpected reboot or disconnect and cleanly unmounts it via `umount` or `diskutil unmount force`.
3. **Starts OpenList Safely**: Runs `./openlist start --data "$HOME/openlist/data"` from `$HOME/openlist` so the database path is never lost regardless of where the script is called from.
4. **Prevents Race Conditions**: Polls `http://localhost:5244` every second (up to 15 seconds) until OpenList is fully initialized before invoking `rclone mount`.
5. **Mounts with Finder-Tuned VFS Caching**: Mounts `openlist:` to `~/webdav` as a background daemon (`--daemon`) and displays it as **OpenList** in macOS Finder.

### `rclone mount` Parameters Explained

| Flag | Value | Purpose |
| :--- | :--- | :--- |
| `--vfs-cache-mode` | `full` | Enables full read/write disk caching. Required for macOS Finder operations (random read/write, file overwrites, media scrubbing). |
| `--vfs-cache-max-size` | `30G` | Caps local disk cache at 30 GB; automatically evicts oldest files using LRU when full. |
| `--vfs-cache-max-age` | `24h` | Removes cached files 24 hours after their last access. |
| `--vfs-read-chunk-size` | `64M` | Starts streaming downloads in 64 MB chunks. |
| `--vfs-read-chunk-size-limit` | `1G` | Doubles sequential read chunk size up to 1 GB for smooth 4K video playback and large file transfers. |
| `--buffer-size` | `32M` | Allocates 32 MB of RAM buffer per open file to smooth out network jitter. |
| `--dir-cache-time` | `12h` | Caches directory trees in memory for 12 hours so browsing folders in Finder feels instant. |
| `--no-modtime` | *(flag)* | Skips extra API calls to read/update file modification times. |
| `--no-checksum` | *(flag)* | Disables MD5/SHA1 checksum checks to avoid incompatibilities across cloud providers. |
| `--exclude` | `".DS_Store"`, `"._*"` | Prevents macOS Finder from uploading hidden metadata files to your cloud drives. |
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
     /bin/bash "$HOME/openlist/mount_openlist.sh"
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

### Manually Unmount the Drive
```bash
umount ~/webdav || diskutil unmount force ~/webdav
```

### Stop or Restart OpenList
```bash
cd ~/openlist
./openlist stop
./openlist restart
```

### View Logs for Troubleshooting
If the drive does not appear in Finder or files fail to open, check the `rclone` and `OpenList` logs:
```bash
# View rclone mount logs
tail -n 50 -f ~/openlist/rclone.log

# View OpenList server logs
tail -n 50 -f ~/openlist/data/log/log.log
```
