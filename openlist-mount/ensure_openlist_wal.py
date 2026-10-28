#!/usr/bin/env python3
"""Prepare the SQLite database before mount_openlist.sh starts OpenList."""
import fcntl
from contextlib import closing
import json
import os
from pathlib import Path
import shutil
import signal
import sqlite3
import subprocess
import sys
import time


def info(message):
    print("[Info] " + message, flush=True)


def server_pids(root):
    result = subprocess.run(
        ["ps", "-ww", "-axo", "pid=,command="],
        check=True, capture_output=True, text=True, timeout=10,
    )
    prefix = str(root / "openlist") + " server"
    pids = []
    for line in result.stdout.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and (fields[1] == prefix or fields[1].startswith(prefix + " ")):
            pids.append(int(fields[0]))
    return pids


def database_path(root):
    config_path = root / "data/config.json"
    config = json.loads(config_path.read_text()) if config_path.exists() else {}
    database = config.get("database", {})
    db_type = database.get("type", "sqlite3")
    filename = database.get("db_file", "data/data.db")
    if not config.get("force", False):
        db_type = os.environ.get("OPENLIST_DB_TYPE", db_type)
        filename = os.environ.get("OPENLIST_DB_FILE", filename)
    if db_type != "sqlite3":
        info("数据库不是 SQLite，跳过 WAL 检查。")
        return None
    path = Path(filename)
    if not path.is_absolute():
        path = root / path
    if path.suffix != ".db":
        raise RuntimeError("SQLite db_file 必须是 .db 文件，拒绝修改：" + str(path))
    return path.resolve()


def ensure_wal(root):
    path = database_path(root)
    if path is None:
        return
    (root / "data").mkdir(parents=True, exist_ok=True)
    with (root / "data/.openlist-wal.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("另一个挂载正在检查 WAL，请稍后再试。")

        # Reading the header does not contend with a live SQLite transaction.
        if path.exists():
            with path.open("rb") as db_file:
                header = db_file.read(20)
            if len(header) == 20 and header[:16] == b"SQLite format 3\x00" and header[18:20] == b"\x02\x02":
                info("SQLite 已启用 WAL，无需转换或重启。")
                return
            if header and (len(header) != 20 or header[:16] != b"SQLite format 3\x00"):
                raise RuntimeError("数据库文件头无效，拒绝修改：" + str(path))

        mounts = subprocess.run(["mount"], check=True, capture_output=True, text=True, timeout=10)
        if " on " + str(Path.home() / "webdav") + " (" in mounts.stdout:
            raise RuntimeError("请先运行 umount_openlist.sh，再转换 WAL。")

        pids = server_pids(root)
        if pids:
            info("转换 WAL 前停止此目录的 OpenList，等待数据库连接释放。")
            for pid in pids:
                try:
                    os.kill(pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            deadline = time.monotonic() + 30
            while server_pids(root):
                if time.monotonic() >= deadline:
                    raise RuntimeError("OpenList 未在 30 秒内退出，未备份或转换数据库。")
                time.sleep(0.5)

        if path.exists():
            # Never mistake a failed occupancy check for an unused database.
            owners = subprocess.run(
                ["lsof", "-nP", "-Fpc", str(path)],
                capture_output=True, text=True, timeout=10,
            )
            if owners.stdout or owners.stderr or owners.returncode not in (0, 1):
                raise RuntimeError("数据库仍被占用或无法确认占用状态，未转换：" + str(path))

        if path.exists() and path.stat().st_size:
            backup = root / "data" / ("wal-backup-" + time.strftime("%Y%m%d-%H%M%S") + "-" + str(os.getpid()))
            backup.mkdir(mode=0o700)
            # Preserve the journal before opening SQLite and triggering recovery.
            for suffix in ("", "-journal", "-wal", "-shm"):
                source = Path(str(path) + suffix)
                if source.exists():
                    destination = backup / ("data.db" + suffix)
                    shutil.copy2(str(source), str(destination))
                    destination.chmod(0o600)
            (backup / "original-path.txt").write_text(str(path) + "\n")
            info("已备份数据库及伴随文件：" + str(backup))

        path.parent.mkdir(parents=True, exist_ok=True)
        with closing(sqlite3.connect(str(path), timeout=5, isolation_level=None)) as connection:
            check = connection.execute("PRAGMA quick_check").fetchall()
            if check != [("ok",)]:
                raise RuntimeError("数据库完整性检查失败，未转换 WAL：" + repr(check))
            mode = connection.execute("PRAGMA journal_mode=WAL").fetchone()[0]
            if mode.lower() != "wal":
                raise RuntimeError("未能启用 WAL，当前模式：" + mode)
            if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
                raise RuntimeError("WAL 转换后的完整性检查失败，请检查备份。")
        info("SQLite WAL 已启用，完整性检查通过。")


if __name__ == "__main__":
    try:
        ensure_wal(Path(__file__).resolve().parent)
    except (OSError, ValueError, RuntimeError, sqlite3.Error, subprocess.SubprocessError) as error:
        print("[Error] WAL 准备失败：" + str(error), file=sys.stderr)
        sys.exit(1)
