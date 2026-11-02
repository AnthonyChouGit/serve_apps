# FRP Reverse Proxy Deployment (Docker Compose)

Deploy **FRP** (`snowdreamtech/frps` and `snowdreamtech/frpc`) to expose internal server ports (such as SFTP or SSH) to the public internet through a VPS, using bridge networking with minimal exposed ports.

```text
[Client / macOS] ──> [VPS: frps (:7000 / :6000)] ◄─── (frpc) ─── [Internal Linux Server (:2222)]
```

---

## 1. Deploy frps on Public VPS

1. On your VPS, create a directory containing `docker-compose.yml` and `frps.toml` from `./frps`.
2. Configure `frps.toml`:
   - Change `auth.token` to a secure random token.
   - Adjust `allowPorts` to limit which remote ports clients can bind (e.g. `6000`).
3. Ensure VPS firewall / security group opens TCP `7000` (frp control) and `6000` (service port).
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
   - Under `[[proxies]]`, specify `localPort` (e.g. `2222` for SFTP) and `remotePort` (e.g. `6000`).
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
sftp -P 6000 root@<VPS_IP>

# Example rclone remote setup
rclone config create sftp sftp host <VPS_IP> port 6000 user root pass your_password
```
