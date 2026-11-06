# FRP Reverse Proxy Deployment (Docker Compose)

Deploy **FRP** (`snowdreamtech/frps` and `snowdreamtech/frpc`) to expose internal server ports (such as SFTP or SSH) to the public internet through a VPS, using bridge networking with minimal exposed ports.

```text
[Client / macOS] ──> [VPS: frps (:19473 / :18635)] ◄─── (frpc) ─── [Internal Linux Server (:18422)]
```

---

## 1. Deploy frps on Public VPS

1. On your VPS, create a directory containing `docker-compose.yml` and `frps.toml` from `./frps`.
2. Configure `frps.toml`:
   - Change `auth.token` to a secure random token.
   - Adjust `allowPorts` to limit which remote ports clients can bind (e.g. `18635`).
3. Ensure VPS firewall / security group opens TCP/UDP `19473` (frp control & QUIC) and TCP `18635` (service port).
4. Start the server:
   ```bash
   docker compose up -d
   ```

---

## 2. Deploy frpc on Internal Server

1. On the internal server, create a directory containing `docker-compose.yml` and `frpc.toml` from `./frpc`.
2. Configure `frpc.toml`:
   - Set `serverAddr` to your VPS public IP / domain.
   - Set `auth.token` to match `frps.toml`.
   - Under `[[proxies]]`, specify `localPort` (e.g. `18422` for SFTP) and `remotePort` (e.g. `18635`).
3. Start the client:
   ```bash
   docker compose up -d
   ```
4. Verify connection status:
   ```bash
   docker compose logs -f
   # Output should confirm: start proxy success
   ```

---

## 3. Connect from Client

Connect to your service using the VPS public IP and mapped `remotePort`:

```bash
# Example SSH/SFTP connection
sftp -P 18635 root@<VPS_IP>

# Example rclone remote setup
rclone config create sftp sftp host <VPS_IP> port 18635 user root pass your_password
```
