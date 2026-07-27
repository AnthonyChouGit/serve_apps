# Nginx with Certbot Auto-Certification

This project sets up an Nginx HTTPS server with Certbot auto-certification using Docker Compose. It automatically obtains and renews Let's Encrypt SSL certificates for your domains.

## Features
- **Nginx Web Server**: High-performance reverse proxy and web server.
- **Auto-Certification**: Automatic Let's Encrypt SSL certificate issuance and renewal via Certbot.
- **Auto-Reload**: Automatically reloads Nginx when new certificates are issued.

## Directory Structure
- `docker-compose.yml`: Main deployment file defining Nginx and Certbot services.
- `init_cert.sh`: Script to initialize the first SSL certificate.
- `auto_renew.sh`: Background script running inside the Certbot container to check and renew certificates periodically.
- `auto_reload.sh`: Background script running inside the Nginx container to reload the configuration when certificates are updated.
- `my_nginx.conf`: Nginx server configuration file.

## Usage

### 1. Configure Domains
Edit `init_cert.sh` and `my_nginx.conf` to replace the placeholder domains (e.g., `example.com`) and email (`your_email@example.com`) with your actual domains and contact email.

### 2. Initialize Certificates & Start Services
Run the initialization script which will fetch the initial certificates and start the Docker Compose services:
```bash
./init_cert.sh
docker compose up -d
```

### 3. Automatic Renewal
Once started, the `certbot` container will automatically attempt to renew the certificates every 24 hours. If renewed, the `nginx` container will reload its configuration automatically to apply the new certificates.
