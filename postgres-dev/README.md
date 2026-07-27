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
