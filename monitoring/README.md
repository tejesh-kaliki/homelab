# Monitoring — Beszel

Tracks CPU, RAM, disk, and network usage across all running Docker containers via Beszel hub + agent.

## Services

| Service | Port | Purpose |
|---|---|---|
| beszel | 8090 | Web UI and hub — stores metrics, shows dashboards |
| beszel-agent | 45876 | Runs on the host, scrapes Docker and system stats |

## Setup

Copy `.env.example` to `.env` and fill in the required values:

```
BESZEL_KEY=<hub public key>
BESZEL_TOKEN=<agent token>
```

Then start the stack:

```bash
docker compose up -d
```

## First boot

Open Beszel at http://localhost:8090 — create an admin account on first visit.

Add the local agent from the UI: use `host.docker.internal` (or `localhost` since the agent uses `network_mode: host`) on port `45876`. Copy the key and token shown there into your `.env`, then restart the agent container.

## Notes

- Beszel data (metrics history, users, config) is stored in the `beszel_data` volume — survives container restarts
- Agent state is in `beszel_agent_data`
- To monitor additional disks, uncomment and adjust the `/extra-filesystems` volume mount in `docker-compose.yml`
