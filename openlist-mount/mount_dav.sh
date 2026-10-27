#!/bin/bash
# ==============================================================================
# 脚本名称: mount_dav.sh
# 功能描述: 开机自动启动 OpenList 并通过 rclone 将其 WebDAV 挂载至本地 ~/webdav
# 适用平台: macOS (Apple Silicon & Intel)
# ==============================================================================

# 1. 补齐环境变量 PATH
# 优先使用 ~/openlist 目录下的官方 cmount 增强版 rclone，同时补全 Homebrew 路径
export PATH="$HOME/openlist:/opt/homebrew/bin:/usr/local/bin:$PATH"

# 2. 检查并清理残留挂载与旧的 rclone 守护进程
# 注意：FUSE-T 下仅执行 umount 不会立即终止后台 rclone --daemon 进程，
# 若不先结束旧 rclone 进程，它在退出时会把内存中的 .DS_Store 重新写回 VFS 缓存目录！
if mount | grep -q "$HOME/webdav" || pgrep -f "rclone mount openlist:" >/dev/null 2>&1; then
    echo "[Info] 正在卸载旧挂载并停止残留的 rclone 后台进程..."
    umount "$HOME/webdav" 2>/dev/null || diskutil unmount force "$HOME/webdav" 2>/dev/null
    pkill -TERM -f "rclone mount openlist:" 2>/dev/null || true
    for i in {1..10}; do
        pgrep -f "rclone mount openlist:" >/dev/null 2>&1 || break
        sleep 0.5
    done
    pkill -KILL -f "rclone mount openlist:" 2>/dev/null || true
fi

# 3. 禁止 macOS Finder 在网络/FUSE-T 挂载盘上生成 .DS_Store，并清理 VFS 缓存残留
# (必须在旧 rclone 进程彻底退出后清理，否则旧进程会把 .DS_Store 重新刷回磁盘)
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true 2>/dev/null || true
mkdir -p "$HOME/webdav"
rm -f "$HOME/Library/Caches/rclone/vfs/openlist/.DS_Store" \
      "$HOME/Library/Caches/rclone/vfsMeta/openlist/.DS_Store" 2>/dev/null || true
find "$HOME/Library/Caches/rclone/vfs/openlist" "$HOME/Library/Caches/rclone/vfsMeta/openlist" \
    \( -name ".DS_Store" -o -name "._*" \) -delete 2>/dev/null || true

# 4. 启动 OpenList 服务
# 锁定进入 ~/openlist 目录并显式指定 --data，防止在其它路径调用时生成空白数据库
echo "[Info] 正在启动 OpenList 服务..."
(cd "$HOME/openlist" && ./openlist start --data "$HOME/openlist/data")

# 5. 等待 OpenList 端口就绪（防止时序竞态）
# OpenList 后台启动需要 1~2 秒初始化数据库并监听 5244 端口。
# 若 rclone 立即挂载，可能因连接不上本地端口而直接报错退出。
echo "[Info] 等待 OpenList 本地服务 (5244 端口) 就绪..."
OPENLIST_READY=0
for i in {1..15}; do
    if curl -s -m 1 "http://localhost:5244" > /dev/null 2>&1; then
        OPENLIST_READY=1
        echo "[Info] OpenList 服务已成功就绪！"
        break
    fi
    sleep 1
done

if [ $OPENLIST_READY -ne 1 ]; then
    echo "[Error] OpenList 未能在 15 秒内就绪，终止挂载！"
    exit 1
fi

# 6. 使用 rclone 挂载 WebDAV 到本地
# 将挂载参数定义为数组，允许在脚本中为每个参数逐行添加详细中文注释，且避免反斜杠换行失效
RCLONE_OPTS=(
    # 【核心缓存模式】full 开启完整的读写缓存，支持随机读写、覆盖和截断，macOS Finder 正常工作必需
    --vfs-cache-mode full

    # 【磁盘缓存上限】本地最多占用 30GB 硬盘空间，超过后按 LRU（最近最少使用）自动清理旧文件
    --vfs-cache-max-size 30G

    # 【缓存生存时间】缓存文件在最后一次被读取或写入 24 小时后自动释放
    --vfs-cache-max-age 24h

    # 【分块读取起始大小】流式读取文件时初始从 64MB 开始读取
    --vfs-read-chunk-size 64M

    # 【分块读取上限】连续顺序读取时分块逐步翻倍增长至最大 1GB，大幅提升大文件吞吐性能
    --vfs-read-chunk-size-limit 1G

    # 【内存缓冲大小】每个打开文件的内存缓冲区（RAM）大小为 32MB，平滑网络波动
    --buffer-size 32M

    # 【目录缓存时间】针对实时同步场景设为 15 秒（WebDAV 不支持变更推送，过长会导致跨设备新文件不显示）
    --dir-cache-time 15s

    # 【写回延迟】本地文件关闭后等待 3 秒即触发后台上传至网盘（默认 5 秒）
    --vfs-write-back 3s

    # 【忽略修改时间（FUSE-T 必需）】FUSE-T 底层使用 NFS 客户端，Finder 仅读取/预览文件时也会改动 mtime，
    # 若不加 --no-modtime，会导致 Finder 浏览文件时触发 rclone 误判文件被修改并重新上传整个文件！
    --no-modtime

    # 【禁用校验和】关闭文件哈希（MD5/SHA1）校验，避免因网盘不支持或分片算法差异导致卡顿与报错
    --no-checksum

    # 【过滤 macOS 隐藏文件与扩展属性】防止访达将 .DS_Store、._* 及 com.apple.* 属性上传导致报错
    --noappledouble
    --noapplexattr
    --exclude ".DS_Store"
    --exclude "._*"

    # 【Finder 卷标名称】在 macOS 访达侧边栏、桌面及磁盘列表中显示的挂载名称
    --volname "OpenList"

    # 【缓存清理轮询】每隔 1 分钟检查一次本地缓存占用，确保不超过 30G 配额
    --vfs-cache-poll-interval 1m

    # 【日志输出文件】将运行日志输出到该文件，方便后台静默执行时排查异常
    --log-file "$HOME/openlist/rclone.log"

    # 【日志记录级别】NOTICE 级别，只记录挂载关键事件与错误警告，避免日志文件过大
    --log-level NOTICE

    # 【后台守护运行】让 rclone 挂载脱离当前终端会话，并在系统后台静默常驻
    --daemon
)

echo "[Info] 开始通过 rclone 挂载 openlist: 到 ~/webdav ..."
rclone mount openlist: "$HOME/webdav" "${RCLONE_OPTS[@]}"

echo "[Success] OpenList WebDAV 挂载已启动！"
