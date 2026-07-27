# SyncTV Deployment

This directory contains the Docker Compose setup for [SyncTV](https://github.com/synctv-org/synctv), a program that allows you to watch movies and videos synchronously with friends.

## Configuration
- **Data Persistence**: Uses a local `./data` folder to persist application data (`/root/.synctv`).
- **Database**: Configured to use a PostgreSQL database (`SYNCTV_DATABASE_TYPE=postgres`).
- **Network**: Connects to the external `nginx_network`. This implies it is intended to be reverse-proxied (e.g., using the `nginx-with-certbot` setup in this repository).

## Usage
1. Start the SyncTV service:
   ```bash
   docker compose up -d
   ```
2. Since it exposes port `8080` only to the `nginx_network`, ensure your Nginx reverse proxy is configured to route traffic to the `synctv:8080` upstream.

### 💡 What if I am not using Nginx?
If you are not using Nginx (or another reverse proxy on the same Docker network), you can map the port directly to your host machine. To do this, modify `docker-compose.yml` by replacing the `expose` section with a `ports` section:

```yaml
    ports:
      - "8080:8080/tcp"
```
You can then access SyncTV directly via `http://your-server-ip:8080`.

### 🌐 External Networks
This setup uses an external Docker network named `nginx_network` to communicate with the reverse proxy.
- **How to create it**: If the network doesn't exist yet, you must create it manually before starting the container:
  ```bash
  docker network create nginx_network
  ```
- **If you don't need it**: If you are not using Nginx and have mapped the ports directly as shown above, you can remove or comment out the `networks` sections in `docker-compose.yml`.
