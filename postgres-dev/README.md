# PostgreSQL Development Database

A quick-start Docker Compose configuration for a local PostgreSQL 18 database, perfect for development and testing.

## Configuration
- **Image**: `postgres:18`
- **Volume**: A persistent Docker volume (`postgres-dev`) is used to store database data at `/var/lib/postgres`.
- **Port**: Mapped to host port `543` (to avoid conflicts with local Postgres installations on 5432).
- **Network**: Connects to the external `dev_network`.

## Usage
1. Edit `docker-compose.yml` to set your desired credentials:
   - `POSTGRES_USER`
   - `POSTGRES_PASSWORD`
   - `POSTGRES_DB`
2. Start the database:
   ```bash
   docker compose up -d
   ```

### 🌐 External Networks
This setup uses an external Docker network named `dev_network` to allow other development containers (like your Node.js apps) to connect to this database securely without using the host network.
- **How to create it**: If the network doesn't exist yet, you must create it manually before starting the container:
  ```bash
  docker network create dev_network
  ```
- **If you don't need it**: If you only plan to access the database via the exposed host port (`543`) and don't need internal Docker DNS resolution, you can remove or comment out the `networks` sections in `docker-compose.yml`.
