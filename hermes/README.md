# Hermes Agent Deployment

This directory contains the Docker Compose setup for [Hermes Agent](https://hermes-agent.nousresearch.com/) by Nous Research, an autonomous AI agent featuring continuous self-improvement, persistent memory, and multi-platform gateway integrations (Telegram, Discord, Slack, etc.).

## Overview

The setup provides a containerized environment running Hermes in gateway mode:
- **Persistent Data**: All configurations, credentials, sessions, skills, and memories are stored locally in `./.agent` (mounted to `/opt/data` inside the container).
- **Gateway API**: Exposes port `8642` for the gateway's OpenAI-compatible API and health checks.
- **Resource Constraints**: Preconfigured limits of 4 CPUs and 7GB RAM to ensure stable long-running performance.

## Directory Structure

- `docker-compose.yml`: Defines the persistent Hermes Agent gateway container service, ports, volume mounts, and resource allocations.
- `setup.sh`: Quick interactive setup script to run the Hermes initialization wizard.

## Usage

### 1. Run Initial Setup Wizard

Before running the agent as a background service, run the interactive setup wizard to configure your LLM providers (e.g., Nous Portal, OpenAI, Anthropic) and messaging integrations (e.g., Telegram bot token):

```bash
chmod +x setup.sh
./setup.sh
```

> **Note**: This runs `nousresearch/hermes-agent setup` in an interactive container. All configuration and keys will be saved to `./.agent`.

### 2. Start the Gateway Service

Once configured, start the Hermes Agent gateway in detached mode:

```bash
docker compose up -d
```

### 3. Check Logs & Status

Monitor the gateway process and interaction logs:

```bash
docker compose logs -f
```

To stop the service:

```bash
docker compose down
```

## Configuration Options

### Environment Variables
You can customize the environment in `docker-compose.yml` or configure them via the setup wizard into `./.agent/.env`.

If you prefer passing environment variables directly via `docker-compose.yml`, uncomment the relevant lines under `environment`:
- `ANTHROPIC_API_KEY`: Anthropic Claude API key
- `OPENAI_API_KEY`: OpenAI API key
- `TELEGRAM_BOT_TOKEN`: Telegram bot token for messaging platform integration

### Enabling the Web Dashboard
Hermes Agent includes an optional web dashboard. To enable it:
1. In `docker-compose.yml`, uncomment the dashboard port mapping:
   ```yaml
   ports:
     - "8642:8642"   # gateway API
     - "9119:9119"   # dashboard (only reached when HERMES_DASHBOARD=1)
   ```
2. Uncomment the dashboard environment variable:
   ```yaml
   environment:
     - HERMES_DASHBOARD=1
   ```
3. Restart the container:
   ```bash
   docker compose up -d
   ```
4. Access the dashboard at `http://<your-server-ip>:9119`.
