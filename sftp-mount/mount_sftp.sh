#!/bin/bash
# 通过 rclone 将远程树莓派 SFTP 容器挂载为本地磁盘

RCLONE="$HOME/Scripts/rclone"    # 使用支持 FUSE-T (cmount) 的官方 rclone 可执行文件
REMOTE="sftp:/data"              # rclone 配置的远程名称及容器内挂载目录
MOUNT_POINT="$HOME/data"         # 本地挂载路径

# 确保本地挂载目录存在
mkdir -p "$MOUNT_POINT"

# 启动 rclone 挂载
"$RCLONE" mount "$REMOTE" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 2G \
    --vfs-cache-max-age 10m \
    --buffer-size 16M \
    --dir-cache-time 1m \
    --no-modtime \
    --noapplexattr \
    --volname "Pi_Disk" \
    --log-file "$HOME/Scripts/rclone_sftp.log" \
    --log-level NOTICE \
    --daemon

echo "已将 $REMOTE 挂载到 $MOUNT_POINT"
