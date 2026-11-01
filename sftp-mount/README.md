# Remote SFTP Disk Mount (EasyTier + Docker SFTP + rclone)

Mount an external or secondary drive on a Linux server as a local disk on macOS over a P2P virtual LAN using **EasyTier**, a lightweight **Alpine SFTP container**, and **rclone (`cmount`) + FUSE-T**.

```text
[Server Drive (/mnt/mydisk)] -> [Alpine SFTP Container (:2222)] ◄══ EasyTier P2P (10.144.144.0/24) ══► [macOS rclone + FUSE-T (~/data)]
```

---

## 1. Format & Mount Drive on Linux Server

Connect the drive to the server (use a blue **USB 3.0** port if connecting via USB).

### 1.1 Identify & Format the Drive

```bash
# 1. Check the drive device name (typically /dev/sda)
lsblk

# 2. Format the drive as ext4 (or partition first with `sudo fdisk /dev/sda` using `g` for GPT and `n` for partitions)
sudo mkfs.ext4 /dev/sda
```

*(Optional multi-partition setup: run `sudo fdisk /dev/sda`, press `g` to create a GPT table, `n` to create Partition 1 for Linux storage (`mkfs.ext4 /dev/sda1`) and Partition 2 for cross-platform use (`mkfs.exfat /dev/sda2`), then `w` to write.)*

### 1.2 Mount & Configure Auto-Mount on Boot (`/etc/fstab`)

```bash
# 1. Create the mount directory
sudo mkdir -p /mnt/mydisk

# 2. Get the partition UUID
sudo blkid /dev/sda
```

Copy the `UUID="..."` value and append a line to `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

```text
UUID=YOUR_DRIVE_UUID /mnt/mydisk ext4 defaults,noatime 0 2
```

Mount and grant permissions:

```bash
sudo mount -a
sudo chown -R $USER:$USER /mnt/mydisk
df -h /mnt/mydisk
```

---

## 2. Deploy Lightweight SFTP Container (Server)

This directory includes an Alpine-based `Dockerfile` (~15 MB total image size) and `docker-compose.yml` that maps `/mnt/mydisk` to `/data` inside the container on port `2222`.

1. Edit `Dockerfile` and replace `your_password` with your desired root password:
   ```dockerfile
   && echo "root:your_password" | chpasswd \
   ```
2. Build and start the container on the server:
   ```bash
   docker compose up -d --build
   ```

---

## 3. Configure EasyTier Virtual LAN

### 3.1 Server Side

Edit `docker-compose-easytier.yml` to set your `--network-name` and `--network-secret`. The server is pinned to `10.144.144.1/24`:

```bash
docker compose -f docker-compose-easytier.yml up -d
```

### 3.2 Client Side (macOS)

Open **EasyTier GUI** on macOS, switch to TOML configuration mode, paste the contents of `easytier-client.toml` (replacing `your_network_name` and `your_network_secret` to match the server), and start the network.

- **Server Virtual IP**: `10.144.144.1`
- **macOS Client Virtual IP**: `10.144.144.2`

*(Tip: Updated community public nodes can be found at <https://uptime.easytier.cn>.)*

---

## 4. Mount on macOS via rclone & FUSE-T

### 4.1 Install FUSE-T & Official `rclone`

Homebrew's `rclone` disables `mount`. Download the official binary with `cmount` support into `~/Scripts`:

```bash
# 1. Install FUSE-T
brew tap macos-fuse-t/homebrew-cask
brew install fuse-t

# 2. Prepare ~/Scripts and copy mount/unmount scripts
mkdir -p ~/Scripts
cp ./mount_sftp.sh ./umount_sftp.sh ~/Scripts/

# 3. Download official rclone (Apple Silicon arm64)
curl -L -o /tmp/rclone.zip https://downloads.rclone.org/rclone-current-osx-arm64.zip
unzip -j /tmp/rclone.zip "*/rclone" -d ~/Scripts/
rm -f /tmp/rclone.zip

chmod +x ~/Scripts/rclone ~/Scripts/mount_sftp.sh ~/Scripts/umount_sftp.sh
xattr -cr ~/Scripts
```

### 4.2 Create the `sftp` Remote in `rclone`

Run a single command to create the `sftp` remote pointing to the SFTP container (`10.144.144.1:2222`):

```bash
~/Scripts/rclone config create sftp sftp host 10.144.144.1 port 2222 user root pass your_password
```

### 4.3 Mount & Unmount

- **Mount to `~/data`**:
  ```bash
  ~/Scripts/mount_sftp.sh
  ```
- **Unmount `~/data`**:
  ```bash
  ~/Scripts/umount_sftp.sh
  ```
