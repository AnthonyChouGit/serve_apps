# Hysteria2 Proxy Server

This directory contains the configuration to deploy a Hysteria2 proxy server.

## Configuration Details (`config.yml`)

Here is an explanation of the key parts of the configuration:

- **`listen`**: The port range the server listens on for incoming connections (e.g., `:30010-49990`). Port hopping is used to prevent blocking.
- **`tls`**: Specifies the path to the SSL/TLS certificate (`cert`) and private key (`key`). This is required for Hysteria2 to encrypt traffic.
- **`auth`**: Authentication mechanism. In this config, `type: password` is used with a specific password string.
- **`obfs`**: Obfuscation settings to disguise the traffic. We use the `salamander` obfuscation type along with an obfuscation password to bypass DPI (Deep Packet Inspection).

### 💡 Tip: Using ACME for Automatic Certificates
If you do not have a pre-existing TLS certificate, you can comment out the `tls` section and uncomment the `acme` section in `config.yml`. Hysteria2 can automatically fetch a Let's Encrypt certificate for your domain.

> [!IMPORTANT]
> If you decide to use ACME, remember to update your `docker-compose.yml` file:
> 1. Uncomment the `- ./acme:/acme` volume mount so that the generated certificates are persisted.
> 2. Comment out the manual certificate mount (e.g., `- /root/https/certbot/etc/letsencrypt:/etc/letsencrypt:ro`) to avoid conflicts.

> [!WARNING]
> If you choose to use Hysteria2's internal `acme` auto-certification, it will need to listen on **Port 80**. This will conflict if you are running Nginx (or any other web server) on the same machine on Port 80. Ensure Port 80 is available before enabling `acme`.
