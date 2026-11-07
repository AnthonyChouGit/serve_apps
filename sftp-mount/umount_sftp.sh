#!/bin/bash
# 卸载本地 ~/data 挂载点并停止对应的 rclone 服务

MOUNT_POINT="$HOME/data"
LABEL="com.user.rclone.sftp"

# 卸载挂载点（优先使用 umount，失败则回退到 macOS 的 diskutil）
umount "$MOUNT_POINT" 2>/dev/null || diskutil unmount "$MOUNT_POINT" >/dev/null 2>&1 || true

# 停止 launchctl 托管的 rclone 服务及残留进程
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "/tmp/${LABEL}.plist"
pkill -f "rclone mount sftp:/data $MOUNT_POINT" 2>/dev/null || true

echo "已卸载 $MOUNT_POINT"
