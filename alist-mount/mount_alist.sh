#!/bin/bash
# ==============================================================================
# Script Name : mount_alist.sh
# Description : Automatically starts AList and mounts its WebDAV storage to
#               ~/webdav on macOS using the official rclone binary + FUSE-T.
# Platform    : macOS (Apple Silicon & Intel)
# ==============================================================================

# Configuration Variables
ALIST_DIR="$HOME/alist"
MOUNT_POINT="$HOME/webdav"
RCLONE_REMOTE="alist:"

# 1. Configure Environment PATH
# Prioritize $HOME/alist so the official rclone binary (with cmount/FUSE support)
# is used instead of Homebrew's rclone, while keeping Homebrew paths for fuse-t.
export PATH="$ALIST_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"

# 2. Check and Clean Up Stale Mounts
# If the system previously lost power or disconnected abnormally, ~/webdav might
# remain in a stale/hanging state and block new mount attempts.
if mount | grep -q "$MOUNT_POINT"; then
    echo "[Info] Detected existing mount at $MOUNT_POINT. Attempting forced unmount..."
    umount "$MOUNT_POINT" 2>/dev/null || diskutil unmount force "$MOUNT_POINT" 2>/dev/null
    sleep 1
fi

# 3. Ensure Local Mount Directory Exists
mkdir -p "$MOUNT_POINT"

# 4. Start AList Service
# Explicitly specify --data "$ALIST_DIR/data" so AList always loads the right
# database regardless of the working directory from which this script is invoked.
echo "[Info] Starting AList service..."
(cd "$ALIST_DIR" && ./alist start --data "$ALIST_DIR/data")

# 5. Wait for AList Port (5244) to Become Ready (Prevent Race Conditions)
# AList takes 1-2 seconds in the background to initialize its database and bind
# port 5244. Polling prevents rclone from failing immediately on startup.
echo "[Info] Waiting for AList local service (port 5244) to be ready..."
ALIST_READY=0
for i in {1..15}; do
    if curl -s -m 1 "http://localhost:5244" > /dev/null 2>&1; then
        ALIST_READY=1
        echo "[Info] AList service is ready!"
        break
    fi
    sleep 1
done

if [ $ALIST_READY -ne 1 ]; then
    echo "[Error] AList failed to start within 15 seconds. Aborting mount!"
    exit 1
fi

# 6. Mount AList WebDAV to Local Directory via rclone
RCLONE_OPTS=(
    # [Core Cache Mode] "full" enables complete read/write caching, supporting
    # random reads/writes, overwrites, and truncation required by macOS Finder.
    --vfs-cache-mode full

    # [Disk Cache Limit] Cap local cache usage at 30GB; older files are evicted
    # automatically using LRU (Least Recently Used) when full.
    --vfs-cache-max-size 30G

    # [Cache Retention] Evict cached files 24 hours after their last access.
    --vfs-cache-max-age 24h

    # [Initial Read Chunk Size] Start streaming reads in 64MB chunks.
    --vfs-read-chunk-size 64M

    # [Max Read Chunk Size] Double chunk sizes sequentially up to 1GB for high
    # throughput on large files (e.g., 4K videos, archives).
    --vfs-read-chunk-size-limit 1G

    # [Memory Buffer] Allocate a 32MB in-memory buffer per open file to smooth
    # out network fluctuations.
    --buffer-size 32M

    # [Directory Cache Time] Cache directory trees in RAM for 12 hours to make
    # browsing folders in macOS Finder snappy and responsive.
    --dir-cache-time 12h

    # [Skip Modification Time] Avoid extra API round-trips for mtime updates.
    --no-modtime

    # [Disable Checksums] Skip MD5/SHA1 checksum verification to prevent delays
    # or errors across cloud providers with varying hash schemes.
    --no-checksum

    # [Filter macOS Metadata Files] Prevent Finder from uploading .DS_Store and
    # AppleDouble (._*) files to cloud remotes.
    --exclude ".DS_Store"
    --exclude "._*"

    # [Finder Volume Name] Display name shown in macOS Finder sidebar and Desktop.
    --volname "AList"

    # [Cache Poll Interval] Check local cache disk usage every 1 minute.
    --vfs-cache-poll-interval 1m

    # [Log Output] Write rclone runtime logs to file for easy debugging.
    --log-file "$ALIST_DIR/rclone.log"

    # [Log Level] Log NOTICE and above to keep log files concise.
    --log-level NOTICE

    # [Background Daemon] Detach rclone from the terminal session and run in background.
    --daemon
)

echo "[Info] Mounting $RCLONE_REMOTE to $MOUNT_POINT via rclone..."
rclone mount "$RCLONE_REMOTE" "$MOUNT_POINT" "${RCLONE_OPTS[@]}"

echo "[Success] AList WebDAV mount initiated at $MOUNT_POINT!"
