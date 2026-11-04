# Fail2ban Server Hardening & SSH Protection

A production-ready **Fail2ban** configuration and operational guide tailored for **Ubuntu (20.04, 22.04, and 24.04 LTS)**. Protects your server against brute-force attacks on SSH and optional web services (Nginx).

```text
[Internet Attacker] ──> Failed Logins (SSH / Nginx) ──> systemd journald / logfiles
                                                               │
                                                       (Fail2ban Scanner)
                                                               │
                                               Inserts block rule into firewall
                                                               │
                                                     ▼
                                            [UFW / iptables Drop]
```

---

## 1. Quick Start

### Automated Installation
Run the included setup script with root privileges:

```bash
cd fail2ban
sudo ./setup.sh
```

---

## 2. Step-by-Step Manual Setup

### 2.1 Install Fail2ban

```bash
sudo apt update
sudo apt install -y fail2ban
```

### 2.2 Configure `jail.local`

Never edit `/etc/fail2ban/jail.conf` directly, as future package upgrades will overwrite it. Always use `/etc/fail2ban/jail.local`:

```bash
# Copy the provided template to /etc/fail2ban/
sudo cp jail.local /etc/fail2ban/jail.local

# Edit configuration
sudo nano /etc/fail2ban/jail.local
```

### 2.3 Start & Enable Service

```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

Verify service status:
```bash
sudo systemctl status fail2ban
sudo fail2ban-client ping
# Expected output: Server replied: pong
```

---

## 3. Configuration Breakdown (`jail.local`)

### 3.1 Global Defaults (`[DEFAULT]`)

| Parameter | Recommended Value | Description |
| :--- | :--- | :--- |
| `ignoreip` | `127.0.0.1/8 ::1 <YOUR_IP>` | Whitelist IPs that must never be banned. |
| `bantime` | `1h` | Base duration an offending IP remains blocked. |
| `findtime` | `10m` | Time window within which failed attempts are tracked. |
| `maxretry` | `5` | Maximum number of failed attempts allowed within `findtime`. |
| `backend` | `systemd` | **Crucial for Ubuntu 22.04 / 24.04**: directly reads logs from `systemd-journald` (modern Ubuntu releases do not ship `rsyslog` / `/var/log/auth.log` by default). |
| `banaction` | `ufw` | Uses UFW rules to drop packets. (Change to `iptables-multiport` or `nftables-multiport` if not using UFW). |

### 3.2 Progressive Ban Time (Recidive Protection)
By enabling progressive ban increments in `[DEFAULT]`, repeated offenders get banned for exponentially longer periods:

```ini
bantime.increment = true
bantime.rndtime = 30m
bantime.maxtime = 4w
bantime.factor = 1
```

### 3.3 Custom SSH Port
If your SSH daemon runs on a non-standard port (e.g., `2222`), update the `[sshd]` section:

```ini
[sshd]
enabled = true
port = 2222
filter = sshd
maxretry = 5
```

---

## 4. Protecting Web Services (Nginx)

To enable Nginx attack mitigation, ensure Nginx access and error logs are enabled on the host, and toggle `enabled = true` in `/etc/fail2ban/jail.local`:

```ini
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-botsearch]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-bad-request]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 3
```

Reload Fail2ban after saving:
```bash
sudo fail2ban-client reload
```

---

## 5. Important: Fail2ban with Docker Containers

By default, Docker manipulates `iptables` rules directly and routes traffic via the `PREROUTING` and `DOCKER` chains, which bypasses standard UFW/INPUT filters.

If you are protecting containerized applications exposed directly to host ports:
1. Set Fail2ban's `banaction` to target the `DOCKER-USER` chain, or:
2. Bind the container ports strictly to `127.0.0.1` (e.g. `127.0.0.1:8080:80`) and route external traffic through a host-level reverse proxy (e.g. Nginx with Fail2ban).

---

## 6. Operational Cheat Sheet

### Check Overall Status
```bash
# List all active jails
sudo fail2ban-client status
```

### Inspect a Specific Jail (e.g. sshd)
```bash
sudo fail2ban-client status sshd
```
*Output displays:*
* Currently banned IP count and list
* Total banned IP count
* Current failed login attempts

### Unban an IP Address
```bash
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

### Manually Ban an IP Address
```bash
sudo fail2ban-client set sshd banip <IP_ADDRESS>
```

### Reload Configuration Without Dropping Existing Bans
```bash
sudo fail2ban-client reload
```

### Test Regex Matching Against a Log File
```bash
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf
```

### Check SSH Failed Login Attempts
View all failed SSH password attempts recorded by systemd:
```bash
sudo journalctl -u ssh | grep "Failed password"
```
To monitor failed attempts in real time:
```bash
sudo journalctl -u ssh -f | grep --line-buffered "Failed password"
```
*(Note: On Ubuntu/Debian the unit is `ssh`, while on CentOS/RHEL/Fedora it is `sshd`)*

### View Live Logs
```bash
sudo journalctl -u fail2ban -f
# or
sudo tail -f /var/log/fail2ban.log
```

---

## 7. Emergency Recovery (If Locked Out)

If you are locked out of SSH:
1. Log in via your cloud provider's **VNC / Web Serial Console** (which does not pass through SSH/Fail2ban).
2. Unban your IP:
   ```bash
   sudo fail2ban-client set sshd unbanip <YOUR_CLIENT_IP>
   ```
3. Or temporarily stop Fail2ban:
   ```bash
   sudo systemctl stop fail2ban
   ```
4. Add your public IP to `ignoreip` in `/etc/fail2ban/jail.local` and restart Fail2ban:
   ```bash
   sudo systemctl restart fail2ban
   ```
