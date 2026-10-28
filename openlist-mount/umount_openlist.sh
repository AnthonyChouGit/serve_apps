#!/bin/bash
# 卸载 ~/webdav，并停止对应的 rclone 后台进程。
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mount_point="$HOME/webdav"
process_prefix="$script_dir/rclone mount openlist: $mount_point "

mounted() {
    mount | grep -F "fuse-t:/OpenList on $mount_point (" >/dev/null
}

# 只匹配本脚本启动的这个挂载，避免影响其它 rclone 实例。
matching_pids() {
    local pid command
    while read -r pid; do
        command=$(ps -ww -p "$pid" -o command= 2>/dev/null) || continue
        case "$command" in
            "$process_prefix"*) printf '%s\n' "$pid" ;;
        esac
    done < <(pgrep -x rclone 2>/dev/null || true)
}

if mount | grep -F " on $mount_point (" >/dev/null && ! mounted; then
    echo "[Error] $mount_point 挂载了其他文件系统，拒绝卸载。" >&2
    exit 1
fi

# 当前会话若由 launchd 托管 rclone，先移除任务，避免它在卸载后立即重启。
if launchctl list codex.openlist.mount.live >/dev/null 2>&1; then
    launchctl remove codex.openlist.mount.live
    # launchd 发送 TERM 后，给 rclone 时间自行结束并释放挂载点。
    for ((i = 0; i < 20; i++)); do
        if ! mounted && [ -z "$(matching_pids)" ]; then
            break
        fi
        sleep 0.5
    done
fi

if ! mounted && [ -z "$(matching_pids)" ]; then
    echo "[Info] $mount_point 未挂载，对应的 rclone 进程也不存在。"
    exit 0
fi

if mounted; then
    echo "[Info] 正在卸载 $mount_point ..."
    if ! umount "$mount_point" 2>/dev/null && ! diskutil unmount "$mount_point" >/dev/null 2>&1; then
        echo "[Error] 卸载失败，挂载可能仍被占用；未强制停止 rclone。" >&2
        exit 1
    fi
fi

pids=$(matching_pids)
if [ -n "$pids" ]; then
    echo "[Info] 正在停止对应的 rclone 进程..."
    while read -r pid; do
        kill -TERM "$pid" 2>/dev/null || true
    done <<< "$pids"
    for ((i = 0; i < 20; i++)); do
        [ -z "$(matching_pids)" ] && break
        sleep 0.5
    done
fi

if mounted || [ -n "$(matching_pids)" ]; then
    echo "[Error] 挂载或 rclone 进程仍在，请检查占用和 $script_dir/rclone.log。" >&2
    exit 1
fi
echo "[Success] $mount_point 已卸载，对应的 rclone 进程已停止。"
