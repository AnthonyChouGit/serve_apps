# CrowdSec Server & Docker Protection

A concise deployment and operational guide for **CrowdSec** on Ubuntu/Debian — the modern, lightweight, Go-based replacement for Fail2ban with crowdsourced threat intelligence (CAPI) and native Docker (`DOCKER-USER`) firewall integration.

```text
[System / Docker Logs] ──> [CrowdSec Engine (Leaky Bucket)] ◄══► [Global Community Blocklist (CAPI)]
                                         │
                                  (Ban Decisions)
                                         ▼
                      [Firewall Bouncer (ipset / nftables)]
                                         │
                             ┌───────────┴───────────┐
                             ▼                       ▼
                      [Host: INPUT]         [Docker: DOCKER-USER]
```

---

## 1. Why CrowdSec over Fail2ban?

- **Preemptive Global Blocklist (CAPI)**: Automatically blocks tens of thousands of known malicious scanner IPs at the kernel layer before they even make their first connection.
- **Native Docker Protection**: Directly hooks into both `INPUT` and `DOCKER-USER` chains via a single `ipset` hash table ($O(1)$ lookup performance), avoiding UFW/Docker `iptables` conflicts.
- **Smarter Detection (Leaky Bucket)**: Detects fast brute-force (`ssh-bf`), slow brute-force (`ssh-slow-bf`), username enumeration, and pre-auth connection hangs without false-positive lockouts.

---

## 2. Installation (Ubuntu / Debian)

### 2.1 Disable Legacy Fail2ban (If Installed)

```bash
sudo systemctl disable --now fail2ban
```

### 2.2 Install CrowdSec Engine & Firewall Bouncer

```bash
# 1. Add official CrowdSec repository
curl -s https://install.crowdsec.net | sudo sh

# 2. Install the detection engine and iptables/ipset bouncer
sudo apt update
sudo apt install -y crowdsec crowdsec-firewall-bouncer-iptables
```

*During installation, CrowdSec automatically detects running services (such as `sshd` and `nginx`) and enables the corresponding collections and log parsers.*

---

## 3. Enable Docker Container Protection (`DOCKER-USER`)

Edit the firewall bouncer configuration to ensure both host services and Docker mapped ports are protected:

```bash
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

Ensure `INPUT` and `DOCKER-USER` are enabled under `iptables_chains`:

```yaml
iptables_chains:
  - INPUT
  - DOCKER-USER
```

Restart the bouncer to apply:

```bash
sudo systemctl restart crowdsec-firewall-bouncer
```

Verify the rule is active in `DOCKER-USER`:

```bash
sudo iptables -L DOCKER-USER -n -v
```

---

## 4. Monitoring Docker Container Logs (Optional)

CrowdSec can inspect container stdout/stderr directly via the Docker socket without mounting log files. Append a Docker source block to `/etc/crowdsec/acquis.yaml`:

```yaml
---
source: docker
container_name:
  - nginx
labels:
  type: nginx
```

Then restart CrowdSec:

```bash
sudo systemctl restart crowdsec
```

---

## 5. Operational Cheat Sheet (`cscli`)

### View Active Bans (Local Decisions)
```bash
sudo cscli decisions list
```

### View Global Blocklist (CAPI) Sync Status
```bash
# Check CAPI connection status (note: initial CAPI pull can take up to 2 hours on fresh installs)
sudo cscli capi status

# Count total active blocklist entries (including CAPI)
sudo cscli decisions list -a | wc -l
```

### View Log Parsing & Detection Metrics
```bash
sudo cscli metrics
```

### List Installed Detection Scenarios & Collections
```bash
sudo cscli collections list
sudo cscli scenarios list
```

### Manually Ban or Unban an IP
```bash
# Ban an IP for 24 hours
sudo cscli decisions add --ip 1.2.3.4 --duration 24h --reason "manual ban"

# Unban an IP
sudo cscli decisions delete --ip 1.2.3.4
```

### Whitelist Trusted IPs / Subnets
Create or edit `/etc/crowdsec/parsers/s02-enrich/mywhitelists.yaml`:

```yaml
name: my/whitelist
description: "Whitelist trusted IPs"
whitelist:
  reason: "Trusted admin IPs"
  ip:
    - "1.2.3.4"
  cidr:
    - "192.168.0.0/16"
    - "10.144.144.0/24"
```

Reload CrowdSec after editing:
```bash
sudo systemctl reload crowdsec
```
