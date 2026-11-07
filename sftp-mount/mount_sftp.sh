#!/bin/bash
# 通过 rclone 将远程 SFTP 容器挂载为本地磁盘
# 使用 macOS launchctl 托管后台进程，避免退出终端 (Terminal.app) 后触发本地网络权限 (NECP) 阻断

RCLONE="$HOME/Scripts/rclone"    # 使用支持 FUSE-T (cmount) 的官方 rclone 可执行文件
REMOTE="sftp:/data"              # rclone 配置的远程名称及容器内挂载目录
MOUNT_POINT="$HOME/data"         # 本地挂载路径
LOG_FILE="$HOME/Scripts/rclone_sftp.log"
LABEL="com.user.rclone.sftp"
PLIST="/tmp/${LABEL}.plist"

# 确保本地挂载目录存在
mkdir -p "$MOUNT_POINT"

# 如果已有同名服务运行，先清理
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

# 启动 rclone 挂载
#   --vfs-cache-max-age 24h      看过的图片/缩略图 24 小时内直接读本地缓存
#   --vfs-fast-fingerprint       用 大小+修改时间 判断文件是否变化，不在远端计算 md5
#   --sftp-disable-hashcheck     禁止在远端执行 md5sum 等哈希命令（会整文件读盘）
#   --sftp-chunk-size 255k       增大单次读写块，提升高延迟链路下的吞吐
#   --contimeout 5s              连接超时 5 秒快速返回，配合单次重试避免网络断开时卡死 Finder
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${RCLONE}</string>
        <string>mount</string>
        <string>${REMOTE}</string>
        <string>${MOUNT_POINT}</string>
        <string>--vfs-cache-mode</string>
        <string>full</string>
        <string>--vfs-cache-max-size</string>
        <string>5G</string>
        <string>--vfs-cache-max-age</string>
        <string>24h</string>
        <string>--vfs-write-back</string>
        <string>1s</string>
        <string>--vfs-fast-fingerprint</string>
        <string>--dir-cache-time</string>
        <string>10s</string>
        <string>--sftp-chunk-size</string>
        <string>255k</string>
        <string>--sftp-disable-hashcheck</string>
        <string>--contimeout</string>
        <string>5s</string>
        <string>--low-level-retries</string>
        <string>1</string>
        <string>--retries</string>
        <string>1</string>
        <string>--noapplexattr</string>
        <string>--volname</string>
        <string>SFTP_Disk</string>
        <string>--log-file</string>
        <string>${LOG_FILE}</string>
        <string>--log-level</string>
        <string>NOTICE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "已将 $REMOTE 挂载到 $MOUNT_POINT"
