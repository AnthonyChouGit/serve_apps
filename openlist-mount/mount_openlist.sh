#!/bin/bash
# 启动 OpenList，并将其 WebDAV 挂载到 ~/webdav（macOS / FUSE-T）。
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mount_point="$HOME/webdav"
rclone="$script_dir/rclone"

if [ ! -x "$script_dir/openlist" ] || [ ! -x "$rclone" ]; then
    echo "[Error] 找不到可执行的 openlist 或 rclone：$script_dir" >&2
    exit 1
fi

# 只对网络卷有效；~/openlist 等普通本地目录仍可能有 .DS_Store。
if [ "$(defaults read com.apple.desktopservices DSDontWriteNetworkStores 2>/dev/null || true)" != 1 ]; then
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    if pgrep -x Finder >/dev/null 2>&1; then
        killall Finder
        echo "[Info] 已设置 Finder 不写网络卷 .DS_Store，并重启 Finder。"
    else
        echo "[Info] 已设置 Finder 不写网络卷 .DS_Store；Finder 启动时会读取新设置。"
    fi
fi

# 已挂载时直接复用，避免中断尚未写回的 VFS 缓存。
if mount | grep -Fq " on $mount_point ("; then
    echo "[Info] $mount_point 已挂载；要应用新参数或 WAL 修复，请先运行 umount_openlist.sh 再挂载。"
    exit 0
fi
if pgrep -f "$rclone mount openlist: $mount_point" >/dev/null 2>&1; then
    echo "[Error] rclone 进程仍在运行，但 $mount_point 未挂载；请先运行 $script_dir/umount_openlist.sh。" >&2
    exit 1
fi

mkdir -p "$mount_point"
prepare_mountpoint() {
    # Finder 可能在挂载前把 .DS_Store 写进本地挂载点，令 rclone 报 "not empty"。
    if [ "$(ls -A "$mount_point")" = .DS_Store ]; then
        rm "$mount_point/.DS_Store"
    fi
    if [ -n "$(ls -A "$mount_point")" ]; then
        echo "[Error] $mount_point 未挂载但非空；请先检查目录内容，避免覆盖本地文件。" >&2
        exit 1
    fi
}
prepare_mountpoint

# 已是 WAL 时不重启；旧库在停服备份后转换，新库在启动前预建为 WAL。
if ! command -v python3 >/dev/null 2>&1 || [ ! -f "$script_dir/ensure_openlist_wal.py" ]; then
    echo "[Error] WAL 检查需要 python3 和同目录的 ensure_openlist_wal.py。" >&2
    exit 1
fi
python3 "$script_dir/ensure_openlist_wal.py"

if ! curl -sS --max-time 2 -o /dev/null http://127.0.0.1:5244/ 2>/dev/null \
    && ! pgrep -f "$script_dir/openlist server" >/dev/null 2>&1; then
    rm -f "$script_dir/daemon/pid"
    (cd "$script_dir" && "$script_dir/openlist" start --data "$script_dir/data")
fi

# 首页可访问不代表 WebDAV 可用；开机后尤其需要等待存储加载完成。
echo "[Info] 等待 OpenList WebDAV 就绪..."
ready=false
last_error=""
for ((i = 0; i < 30; i++)); do
    if last_error=$("$rclone" lsf openlist: --max-depth 1 --retries 1 \
        --low-level-retries 1 --contimeout 3s --timeout 5s 2>&1 >/dev/null); then
        ready=true
        break
    fi
    sleep 1
done
if [ "$ready" != true ]; then
    echo "[Error] OpenList WebDAV 未就绪：$last_error" >&2
    exit 1
fi

echo "[Info] 挂载 openlist: 到 $mount_point ..."
prepare_mountpoint
mount_args=(mount openlist: "$mount_point"
    --vfs-cache-mode full
    --vfs-cache-max-size 2G
    --vfs-cache-max-age 10m
    --vfs-cache-poll-interval 1m
    --vfs-read-chunk-size 8M
    --vfs-read-chunk-size-limit 64M
    --buffer-size 16M
    --dir-cache-time 1m
    --poll-interval 0
    --vfs-write-back 1s
    --no-modtime
    --noapplexattr
    --volname OpenList
    --log-file "$script_dir/rclone.log"
    --log-level NOTICE)

# launchd 等进程管理器可直接托管前台 rclone；普通调用保持后台挂载。
if [ "${OPENLIST_MOUNT_FOREGROUND:-0}" = 1 ]; then
    exec "$rclone" "${mount_args[@]}"
fi
"$rclone" "${mount_args[@]}" --daemon

if ! mount | grep -Fq " on $mount_point ("; then
    echo "[Error] rclone 已退出，但 $mount_point 未挂载；请查看 $script_dir/rclone.log。" >&2
    exit 1
fi
echo "[Success] $mount_point 已挂载。"
