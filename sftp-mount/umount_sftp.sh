#!/bin/bash
# 卸载本地 ~/data 挂载点并停止对应的 rclone 进程

MOUNT_POINT="$HOME/data"

# 卸载挂载点（优先使用 umount，失败则回退到 macOS 的 diskutil）
umount "$MOUNT_POINT" 2>/dev/null || diskutil unmount "$MOUNT_POINT" >/dev/null 2>&1 || true

# 结束对应的 rclone 后台挂载进程
pkill -f "rclone mount sftp:/data $MOUNT_POINT" 2>/dev/null || true

echo "已卸载 $MOUNT_POINT"
