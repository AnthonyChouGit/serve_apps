#!/bin/bash
# 兼容旧的登录启动项；新安装请使用 mount_openlist.sh。
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec /bin/bash "$script_dir/mount_openlist.sh" "$@"
