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
