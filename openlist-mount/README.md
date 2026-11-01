# macOS Cloud Drive Mounting Guide (OpenList + rclone + FUSE-T)

Mount cloud drives (AliyunDrive, OneDrive, Baidu Netdisk, 139, etc.) as a local volume in macOS Finder using **OpenList**, official **rclone (`cmount`)**, and **FUSE-T**.

```text
[Cloud Storage] -> [OpenList (http://localhost:5244/dav)] -> [rclone + FUSE-T] -> [~/webdav (Finder)]
```

---

## 1. Install Dependencies & Files

> [!IMPORTANT]
> Do **not** use `brew install rclone` (Homebrew disables `rclone mount`). Use the official binary from <https://rclone.org/downloads/> (`go/tags: cmount`).

```bash
# 1. Install FUSE-T
brew tap macos-fuse-t/homebrew-cask
brew install fuse-t

# 2. Prepare ~/openlist and copy scripts
mkdir -p ~/openlist
cp ./mount_openlist.sh ./umount_openlist.sh ./mount_dav.sh ./ensure_openlist_wal.py ~/openlist/

# 3. Download OpenList (Apple Silicon arm64)
curl -L https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-darwin-arm64.tar.gz | tar -xz -C ~/openlist

# 4. Download official rclone (Apple Silicon arm64)
curl -L -o /tmp/rclone.zip https://downloads.rclone.org/rclone-current-osx-arm64.zip
unzip -j /tmp/rclone.zip "*/rclone" -d ~/openlist/
rm -f /tmp/rclone.zip

# 5. Grant executable permissions & remove quarantine attributes
chmod +x ~/openlist/openlist ~/openlist/rclone ~/openlist/*.sh
xattr -cr ~/openlist
```

---

## 2. Configure OpenList

1. Start OpenList and set the administrator password:
   ```bash
   cd ~/openlist
   ./openlist start
   ./openlist admin set YOUR_PASSWORD
   ```
2. Open **<http://localhost:5244>** and sign in as `admin`:
   - **Manage -> Users -> Edit `admin`**: Enable all permissions (especially **WebDAV Read**, **WebDAV Manage**, and upload/modify permissions).
   - **Manage -> Storages -> Add**: Add your cloud storage and set **WebDAV Policy** to **`native_proxy`**.

---

## 3. Configure `rclone`

Create the `openlist` WebDAV remote with a single command (or interactively via `~/openlist/rclone config`):

```bash
~/openlist/rclone config create openlist webdav url http://localhost:5244/dav vendor other user admin pass YOUR_PASSWORD
```

Verify connectivity:

```bash
~/openlist/rclone lsd openlist:
```

---

## 4. Mount & Unmount

- **Start OpenList & Mount to `~/webdav`**:
  ```bash
  ~/openlist/mount_openlist.sh
  ```
- **Unmount `~/webdav` & Stop rclone**:
  ```bash
  ~/openlist/umount_openlist.sh
  ```
- **Check Status / Logs**:
  ```bash
  df -h ~/webdav
  tail -n 50 -f ~/openlist/rclone.log
  ```

---

## 5. Auto-Start on Login (Automator + Login Items)

1. Open **Automator** -> **New Document** -> **Application**.
2. Add the **Run Shell Script** action (`/bin/bash`) with:
   ```bash
   /bin/bash "$HOME/openlist/mount_openlist.sh"
   ```
3. Save as `/Applications/MountOpenList.app`.
4. Add `MountOpenList.app` to **System Settings -> General -> Login Items**.
