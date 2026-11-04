#!/usr/bin/env bash
set -euo pipefail

# Fail2ban Automated Setup Script for Ubuntu
# Target OS: Ubuntu 20.04 / 22.04 / 24.04 LTS

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] This script must be run as root or with sudo." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${SCRIPT_DIR}/jail.local"
CONFIG_DEST="/etc/fail2ban/jail.local"

echo "[1/4] Updating apt package lists and installing Fail2ban..."
apt update -y
apt install -y fail2ban

echo "[2/4] Deploying jail.local configuration..."
if [ -f "${CONFIG_SRC}" ]; then
    cp "${CONFIG_SRC}" "${CONFIG_DEST}"
    chmod 644 "${CONFIG_DEST}"
    echo "      Copied ${CONFIG_SRC} -> ${CONFIG_DEST}"
else
    echo "[!] Configuration template not found at ${CONFIG_SRC}" >&2
    exit 1
fi

echo "[3/4] Enabling and starting fail2ban service..."
systemctl enable fail2ban
systemctl restart fail2ban

echo "[4/4] Verifying Fail2ban status..."
sleep 1
fail2ban-client ping
fail2ban-client status

echo ""
echo "=== Fail2ban installation and setup completed successfully! ==="
echo "Check active sshd jail with: sudo fail2ban-client status sshd"
