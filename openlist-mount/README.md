# macOS Cloud Drive Mounting Guide (OpenList + rclone + FUSE-T)

A setup guide and toolkit for mounting cloud storage providers (AliyunDrive, Baidu Netdisk, OneDrive, Google Drive, Quark, PikPak, SMB/WebDAV, and 40+ others) as a native local drive in macOS Finder using **OpenList** (the community-driven open-source continuation of AList), **rclone (`cmount`)**, and **FUSE-T**, with short directory caching, limited write caching, and optional startup at login.

---

## 1. Overview & Architecture

```
[Cloud Storage Providers]
          │
          ▼
   [OpenList Server]       (Runs locally at http://localhost:5244, exposes WebDAV at /dav)
          │
          ▼
[Official rclone + FUSE-T] (Mounts http://localhost:5244/dav with VFS write caching)
          │
          ▼
   [~/webdav (Finder)]     (Appears as a native "OpenList" volume in macOS Finder)
```

### Included Files in This Directory

| File | Description |
| :--- | :--- |
| `mount_openlist.sh` | Starts OpenList when needed, checks WebDAV readiness, and mounts with short directory caching and limited write caching |
| `umount_openlist.sh` | Unmounts `~/webdav` and stops its matching rclone process without automatic forced unmount or `SIGKILL` |
| `mount_dav.sh` | Compatibility entry point that forwards to `mount_openlist.sh`; copy both files to keep existing login items working |
| `ensure_openlist_wal.py` | Checks SQLite WAL mode, safely stops this installation for migration, preserves a backup, and verifies database integrity |
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

Place the downloaded `openlist` and `rclone` binaries and the scripts in `~/openlist` (`/Users/<your-username>/openlist`). The scripts locate binaries, logs, and the OpenList data directory relative to their own directory, so they can be invoked from another working directory. The mount point is always `~/webdav` (`/Users/<your-username>/webdav`).

### Expected Directory Structure

```text
~/
├── openlist/                   # Working directory for OpenList and rclone
│   ├── openlist                # OpenList executable binary
│   ├── rclone                  # Official rclone binary (with cmount support)
│   ├── mount_openlist.sh       # Startup and mount script
│   ├── umount_openlist.sh      # Unmount and stop the matching rclone process
│   ├── mount_dav.sh            # Compatibility entry point for older login items
│   ├── ensure_openlist_wal.py  # SQLite WAL preparation, called by the mount script
│   ├── rclone.log              # Runtime log generated automatically by rclone
│   └── data/                   # Database & config folder generated automatically by OpenList
└── webdav/                     # Local mount point (appears as "OpenList" in Finder)
```

### Step-by-Step File Installation

Open **Terminal** (`Cmd + Space`, type `Terminal`), navigate to this tutorial folder, and run the following commands to set up `~/openlist`, download the binaries (example below for Apple Silicon `arm64`), and grant executable permissions:

```bash
# 1. Create the target ~/openlist directory and copy the scripts and WAL helper
mkdir -p ~/openlist
cp ./mount_openlist.sh ./umount_openlist.sh ./mount_dav.sh ./ensure_openlist_wal.py ~/openlist/

# The WAL helper requires Python 3 with the standard-library sqlite3 module.
# Install it with `brew install python` if `python3` is unavailable.
python3 -c 'import sqlite3'

# 2. Download and extract OpenList (Apple Silicon arm64)
curl -L https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-darwin-arm64.tar.gz | tar -xz -C ~/openlist

# 3. Download and extract the official rclone binary (Apple Silicon arm64)
curl -L -o /tmp/rclone.zip https://downloads.rclone.org/rclone-current-osx-arm64.zip
unzip -j /tmp/rclone.zip "*/rclone" -d ~/openlist/
rm -f /tmp/rclone.zip

# 4. Ensure all binaries and the script have executable permissions
chmod +x ~/openlist/openlist ~/openlist/rclone ~/openlist/mount_openlist.sh ~/openlist/umount_openlist.sh ~/openlist/mount_dav.sh

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
     - **Cache Expiration**: Keep this short if other devices modify the storage. Both OpenList and rclone (`--dir-cache-time 1m`) cache directory listings. To aim for faster cross-device visibility, use the storage driver's supported cache-disabling or shortest-expiry setting, verify its behavior for your driver, and watch for API rate limits. There is no universal cross-device refresh deadline.
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

## 5. Step 3: Mount Your Cloud Drive

Run the mount script:

```bash
~/openlist/mount_openlist.sh
```

Existing installations can continue calling `~/openlist/mount_dav.sh`, which forwards to `mount_openlist.sh`. Copy all three shell scripts and `ensure_openlist_wal.py` when upgrading; the mount script requires the WAL helper beside it.

### Startup and Repeat Runs

The script uses the `openlist` and `rclone` executables beside it and explicitly supplies the OpenList data path. Before starting the service, it prepares SQLite WAL mode as described below. If neither its local HTTP endpoint nor its matching server process is available, it clears the stale `daemon/pid` file and starts OpenList. It then tries an authenticated WebDAV root listing up to 30 times, using a three-second connection timeout, a five-second I/O timeout, and a one-second pause after a failed attempt. This checks the WebDAV path that rclone will use, rather than treating an accessible homepage as proof that WebDAV is ready. It does not guarantee that every configured storage or subdirectory is healthy.

If `~/webdav` is already mounted, the script exits after its Finder preference check. It **does not change the running mount's parameters**. After editing or upgrading the scripts, apply the new mount parameters by unmounting and mounting again:

```bash
~/openlist/umount_openlist.sh && ~/openlist/mount_openlist.sh
```

The `&&` ensures that mounting proceeds only when unmounting succeeds. Close applications using the volume before this operation and allow local uploads to finish. OpenList itself keeps running when the mount is stopped.

### Automatic SQLite WAL Preparation

`mount_openlist.sh` calls `ensure_openlist_wal.py` before starting OpenList. This works around the SQLite locking failure reproduced with OpenList v4.2.9: its pure-Go SQLite driver ignores `_journal=WAL`, and a long WebDAV read transaction can block token-save commits in rollback-journal mode. A failed commit can leave a transaction on a pooled connection and produce repeated `SQLITE_BUSY` and `cannot start a transaction within a transaction` errors. WAL allows that reader and writer to proceed concurrently; this is a workaround for the reproduced failure, not a guarantee against every database-lock condition.

The helper reads `data/config.json`, resolves relative `database.db_file` paths against the script directory, and honors `OPENLIST_DB_TYPE` / `OPENLIST_DB_FILE` unless `force` is enabled. Non-SQLite databases are skipped. An existing WAL database is recognized from its file header without taking a database lock, restarting OpenList, or creating another backup. A new database is initialized in WAL mode before OpenList first opens it.

For an existing database that is not WAL, the volume must be unmounted. The helper sends `SIGTERM` only to OpenList server commands using the executable beside the scripts, waits up to 30 seconds for them to exit, and checks that no process still holds the database. It then copies the database and any `-journal`, `-wal`, or `-shm` companions into a private `data/wal-backup-<timestamp>-<pid>/` directory **before opening SQLite**, preserving transaction recovery files. It runs `PRAGMA quick_check`, switches to WAL, and checks integrity again. Failure stops mounting; a timed-out shutdown is not followed by a forced kill. The mount script starts the service after successful preparation.

WAL mode persists across restarts, so migration happens only once per database. Already-mounted runs still exit without applying migration; use the unmount-and-mount command above after installing these scripts. If preparation fails after stopping OpenList, inspect the reported error and backup before retrying. Do not delete journal or WAL companions manually.

Verify after mounting:

```bash
sqlite3 ~/openlist/data/data.db 'PRAGMA journal_mode; PRAGMA quick_check;'
~/openlist/rclone lsf openlist: --max-depth 1 --retries 1 --low-level-retries 1 --timeout 10s
```

The database checks should return `wal` and `ok`. Use the configured database path if it differs from this default. WAL files contain OpenList database changes, not cached cloud-file contents. SQLite checkpoints them automatically; long read transactions can delay checkpoints and temporarily grow the file. Keep the database on a local filesystem and preserve its companions when backing it up while the service is running.

References: [SQLite WAL documentation](https://www.sqlite.org/wal.html) and [OpenList issue #3298](https://github.com/OpenListTeam/OpenList/issues/3298).

### Finder Metadata and Mount-Point Checks

When `DSDontWriteNetworkStores` is not enabled, the mount script sets it to `true` and restarts a running Finder with `killall Finder`. If Finder has not started, it reads the preference on startup. This check happens even when the volume is already mounted; a preference that is already enabled does not trigger another Finder restart.

This is a Finder preference for network volumes, not a general ban on `.DS_Store` files. Ordinary local folders such as `~/openlist` can still contain them, and existing files are not removed from remote storage. The scripts do not use `--exclude .DS_Store` as a write blocker and do not delete the VFS cache on each run.

Before mounting, the script removes `.DS_Store` only when it is the sole entry in the **unmounted local mount-point directory**. If any other entry exists, it reports a nonempty directory and stops. It checks again immediately before calling rclone. It does not mount over local files using `--allow-non-empty`.

### Refresh Behavior and Disk Use

Changes from another device become available when the rclone directory cache expires and the directory is queried again. With `--dir-cache-time 1m`, rclone caches directory listings for one minute (preventing recursive `PROPFIND` loops on deeply nested directories while keeping refreshes reasonably prompt), subject to OpenList, cloud-provider, macOS NFS, and Finder caching. One minute is a cache lifetime, **not a timer that pushes a Finder window update every minute**. This WebDAV setup has no rclone change notifications, so `--poll-interval 0` disables unsupported backend polling; it does not disable ordinary directory refreshes.

Local writes are queued for upload one second after the file is closed and idle. This is when an upload can start, not when another device is guaranteed to see a completed upload. Large transfers, network failures, cloud processing, and the other device's cache add latency. Reopen an externally changed file to fetch its updated contents; an application keeping a file open can retain its own data. Avoid editing the same file simultaneously on multiple devices because this mount does not merge competing edits.

`full` mode caches read-only and read/write files on disk with sparse chunking. To prevent uncontrolled disk growth, the mount caps local disk cache at 2 GiB and automatically evicts idle cached files after ten minutes. Small chunking (`8M` initial chunk up to `64M`) combined with a `16M` RAM buffer ensures swift file-header retrieval without exhausting upstream cloud concurrency.

### Current Mount Parameters

| Flag | Value | Purpose |
| :--- | :--- | :--- |
| `--vfs-cache-mode` | `full` | Caches reads and writes on disk using sparse files; files reopen instantly from local cache. |
| `--vfs-cache-max-size` | `2G` | Hard cap of 2 GiB for local disk cache; automatically evicts least recently used files when exceeded. |
| `--vfs-cache-max-age` | `10m` | Makes eligible idle cached files removable after ten minutes since last access. |
| `--vfs-cache-poll-interval` | `1m` | Polls and enforces cache quota and cleanup every minute. |
| `--vfs-read-chunk-size` | `8M` | Starts streaming reads in 8 MiB chunks, quickly delivering headers without hogging provider connection limits. |
| `--vfs-read-chunk-size-limit` | `64M` | Limits max read chunk expansion to 64 MiB to keep concurrent connections short-lived. |
| `--buffer-size` | `16M` | Allocates 16 MiB in-memory buffer per open file to smooth streaming. |
| `--dir-cache-time` | `1m` | Expires rclone's directory listing cache after one minute. |
| `--poll-interval` | `0` | Disables backend change polling for this WebDAV remote. |
| `--vfs-write-back` | `1s` | Starts queued uploads after files are closed and idle for one second. |
| `--no-modtime` | *(flag)* | Disables reading/writing modification time through this mount; retained for the FUSE-T setup. |
| `--noapplexattr` | *(flag)* | Ignores `com.apple.*` extended attributes. |
| `--volname` | `OpenList` | Sets the Finder volume name. |
| `--log-file` | `<script directory>/rclone.log` | Stores rclone runtime errors and notices. |
| `--log-level` | `NOTICE` | Records notices and errors. |
| `--daemon` | *(flag)* | Starts the mount in the background. |

The scripts retain the cache so rclone can recover queued writes. Do not manually erase a cache containing unuploaded files to meet the size target.

Reference: [rclone mount documentation](https://rclone.org/commands/rclone_mount/) describes directory cache expiry, write-cache modes, upload scheduling, and cache-limit exceptions.

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

From now on, every time you log in to your Mac, `MountOpenList.app` will silently start OpenList, check that the WebDAV root can be listed, and mount your cloud storage to `~/webdav` (`OpenList` in Finder).

---

## 7. Daily Operations & Troubleshooting

### Check Mount Status
```bash
mount | grep webdav
# Or check mounted disk space:
df -h ~/webdav
```

### Unmount and Stop the Matching rclone Process

```bash
~/openlist/umount_openlist.sh
```

The unmount script verifies that the volume at `~/webdav` is the expected FUSE-T `OpenList` mount. It performs a normal `umount` (falling back to non-forced `diskutil unmount` on macOS if raw `umount` reports the volume busy), then sends `SIGTERM` only to rclone commands matching the executable beside the script, remote `openlist:`, and mount point `~/webdav`. It waits up to about ten seconds for process exit. A busy mount or a remaining process returns an error instead of automatically forcing an unmount or sending `SIGKILL`. If nothing is mounted and no matching process exists, it exits successfully.

For installations where a session-only launchd job named `codex.openlist.mount.live` was used to keep rclone alive, the script removes that job and waits for it to release the mount before continuing. A normal script invocation does not create this job or install a persistent LaunchAgent. Running the mount from a process runner that cleans up descendants can terminate the daemon when that runner exits; use Terminal or the login-item workflow above to start it normally. When using a process manager such as launchd, `OPENLIST_MOUNT_FOREGROUND=1` runs the same readiness checks and WAL preparation, then replaces the script with foreground rclone using the same mount parameters. The process manager should supervise that foreground process rather than repeatedly invoking a daemonizing script.

### Stop or Restart OpenList

Unmount first if you are about to stop the service:

```bash
~/openlist/umount_openlist.sh && ~/openlist/openlist stop --data "$HOME/openlist/data"
```

To restart the service and remount:

```bash
~/openlist/umount_openlist.sh && ~/openlist/openlist restart --data "$HOME/openlist/data" && ~/openlist/mount_openlist.sh
```

### Upload Failures and Nonempty Mount Points

If uploads keep retrying with `403`, `404`, or `500`, inspect both logs below and fix the WebDAV permissions, storage path, network, or OpenList error first. A reachable homepage can coexist with a failing WebDAV endpoint. For SQLite lock or transaction errors, confirm WAL mode and use the unmount-and-mount workflow to apply the automatic preparation above. Repeatedly remounting an already-WAL database does not fix other service-side failures.

Running the mount script again on an existing mount does not flush its cache, stop uploads, or change its settings. Preserve queued writes until they upload successfully. If manually recovering a cache is unavoidable, stop rclone, save a copy of the affected file and its cache metadata, and establish that you are not discarding the only copy of local edits before making changes.

When mounting fails because `~/webdav` is nonempty, confirm it is unmounted before inspecting its contents. The script handles a lone local `.DS_Store`; move any other local files to a separate directory before mounting instead of using `--allow-non-empty`.

### Cross-Device Changes Appear Slowly

Revisit the affected directory in Finder and reopen the file. If changes remain stale, check the OpenList storage's cache-expiration setting, the cloud provider's listing behavior, and whether WebDAV can list that path successfully. Reducing only rclone's cache cannot eliminate a longer server-side cache. Frequent refreshes also increase backend requests and can trigger provider rate limits.

### View Logs for Troubleshooting
If the drive does not appear in Finder or files fail to open, check the `rclone` and `OpenList` logs:
```bash
# View rclone mount logs
tail -n 50 -f ~/openlist/rclone.log

# View OpenList server logs
tail -n 50 -f ~/openlist/data/log/log.log
```
