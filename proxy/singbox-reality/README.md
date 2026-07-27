# Sing-box VLESS Reality Deployment Guide

This guide explains how to deploy Sing-box using the VLESS Reality protocol via Docker.

## 5. Generate Credentials

Before configuring Sing-box Reality, we need to generate a set of necessary credentials, including a UUID, a Reality keypair (Public Key and Private Key), and a Short ID. Since we are deploying with Docker, we can use the Sing-box Docker image to run these commands without installing Sing-box locally.

1. **Generate UUID**
   Generate a standard UUID using the following Docker command:
   ```bash
   docker run --rm ghcr.io/sagernet/sing-box generate uuid
   ```
2. **Generate Reality Keypair**
   Generate the public and private keys:
   ```bash
   docker run --rm ghcr.io/sagernet/sing-box generate reality-keypair
   ```
   Save the `PrivateKey` and `PublicKey` from the output.
3. **Generate Short ID**
   Generate an 8-byte (16-character) hexadecimal string:
   ```bash
   docker run --rm ghcr.io/sagernet/sing-box generate rand --hex 8
   ```

## 7. Write Configuration File

Fill in your configuration in `data/config.json`. We will use `www.cloudflare.com` as the camouflage domain (SNI) and configure the VLESS Reality inbound.

```json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {"tag": "google", "type": "tls", "server": "8.8.8.8"}
    ]
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "reality-in",
      "listen": "::",
      "listen_port": 50000,
      "users": [
        {
          "name": "main",
          "uuid": "YOUR_UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.cloudflare.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.cloudflare.com",
            "server_port": 443
          },
          "private_key": "YOUR_PRIVATE_KEY",
          "short_id": ["YOUR_SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct-out"}
  ]
}
```
*Make sure to replace `YOUR_UUID`, `YOUR_PRIVATE_KEY`, and `YOUR_SHORT_ID` with the values you just generated.*

## 8. Docker Compose Deployment

Once the configuration is complete, you can start the service directly using Docker Compose:

```bash
docker compose up -d
```
Sing-box is now running! You can connect to your server using any client that supports VLESS Reality.
