#!/bin/bash
# 通过 rclone 将远程 SFTP 容器挂载为本地磁盘

RCLONE="$HOME/Scripts/rclone"    # 使用支持 FUSE-T (cmount) 的官方 rclone 可执行文件
REMOTE="sftp:/data"              # rclone 配置的远程名称及容器内挂载目录
MOUNT_POINT="$HOME/data"         # 本地挂载路径

# 确保本地挂载目录存在
mkdir -p "$MOUNT_POINT"

# 启动 rclone 挂载
#   --vfs-cache-max-age 24h      看过的图片/缩略图 24 小时内直接读本地缓存
#   --vfs-fast-fingerprint       用 大小+修改时间 判断文件是否变化，不在远端计算 md5
#   --sftp-disable-hashcheck     禁止在远端执行 md5sum 等哈希命令（会整文件读盘）
#   --sftp-idle-timeout 10m      空闲连接保留 10 分钟，避免频繁重新 SSH 握手
#   --sftp-chunk-size 255k       增大单次读写块，提升高延迟链路下的吞吐
"$RCLONE" mount "$REMOTE" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-size 5G \
    --vfs-cache-max-age 24h \
    --vfs-write-back 1s \
    --vfs-fast-fingerprint \
    --dir-cache-time 10s \
    --sftp-chunk-size 255k \
    --sftp-disable-hashcheck \
    --sftp-idle-timeout 10m \
    --contimeout 15s \
    --timeout 1m \
    --noapplexattr \
    --volname "SFTP_Disk" \
    --log-file "$HOME/Scripts/rclone_sftp.log" \
    --log-level NOTICE \
    --daemon

echo "已将 $REMOTE 挂载到 $MOUNT_POINT"
