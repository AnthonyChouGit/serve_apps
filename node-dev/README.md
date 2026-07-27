# Node.js Development Environment

This folder contains a containerized development environment for Node.js projects, designed for seamless integration with VS Code.

## Features
- **Custom Dockerfile**: Builds a base Ubuntu image with Node.js and SSH server pre-configured.
- **Persistent Volumes**:
  - `./source:/root/source`: Your code goes here.
  - `./.vscode:/root/.vscode-server`: Persists your VS Code server extensions and configurations across container restarts.
- **Network**: Connects to the external `dev_network`.
- **Ports**: 
  - SSH mapped to port `5555`.
  - Vite/React default port `5173` mapped to the host.

## Usage
1. Build and start the container:
   ```bash
   docker compose up -d --build
   ```
2. Connect to the container via SSH or use the VS Code "Remote - SSH" extension to connect to `localhost:5555`.

### 🌐 External Networks
This setup uses an external Docker network named `dev_network` to communicate with other development containers (like databases).
- **How to create it**: If the network doesn't exist yet, you must create it manually before starting the container:
  ```bash
  docker network create dev_network
  ```
- **If you don't need it**: If this container doesn't need to talk to other containers via a shared network, you can remove or comment out the `networks` sections in `docker-compose.yml`.
