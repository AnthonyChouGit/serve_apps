# Proxy Client Configuration

This directory contains client-side configuration for proxy routing.

## Overview
The `config.yml` file is designed to be used with a proxy client (such as Clash or Mihomo). It defines how your local traffic should be routed through your proxy servers.

### Key Components
- **DNS Rules**: Defines how DNS queries are resolved (using DoH like Alibaba and Cloudflare) and prevents DNS leaks using `fake-ip`.
- **Proxies**: Includes configurations to connect to two proxy endpoints:
  - `Los Angeles`: A Hysteria2 node (configured to match the `hysteria2` server setup in this repository).
  - `Reality Node`: A VLESS-Reality node (configured to match the `singbox-reality` setup in this repository).
- **Proxy Groups**: Defines a `PROXY` group that allows you to select between the available proxy nodes or direct connection.
- **Routing Rules**: 
  - `DIRECT` for local/private IPs and Chinese IP ranges (`GEOIP,CN`).
  - Everything else is routed through the selected `PROXY`.

## Sub-projects
This directory also contains the server-side configurations for the proxy endpoints:
- **[Hysteria2 Server](./hysteria2)**
- **[Sing-box Reality Server](./singbox-reality)**
