# Monitoring - Beszel

Tracks CPU, RAM, disk, network, and Docker container usage via Beszel.

The Beszel hub runs in Docker. The agent can run either as a Docker container or directly on macOS.

## Services

| Service | Port | Purpose |
|---|---|---|
| beszel | 8090 | Web UI and hub, stores metrics and dashboards |
| beszel-agent | 45876 | Optional agent. Run either in Docker or natively on macOS |

## Setup

Copy `.env.example` to `.env` and fill in the required values:

```
BASE_DOMAIN=example.com
BESZEL_KEY=<hub public key>
BESZEL_TOKEN=<agent token>
```

Start the hub:

```bash
docker compose up -d
```

## Option A: Native macOS agent

This is the recommended option when running Docker through OrbStack and you want Beszel to represent the Mac host instead of the Linux VM/container environment.

If the Docker agent is already running, stop and remove it first:

```bash
docker compose -f docker-compose.yml -f docker-compose.agent.yml stop beszel-agent
docker compose -f docker-compose.yml -f docker-compose.agent.yml rm -f beszel-agent
```

Install and start the agent with Homebrew:

```bash
brew tap henrygd/beszel
brew install beszel-agent
mkdir -p ~/.config/beszel ~/.cache/beszel
cp beszel-agent.env.example ~/.config/beszel/beszel-agent.env
```

Edit `~/.config/beszel/beszel-agent.env`:

```dotenv
KEY="ssh-ed25519 AAAA..."
TOKEN="<agent token>"
HUB_URL="https://monitoring.example.com"
LISTEN="45876"
```

Keep the full SSH public key on one line and inside quotes. Without quotes, the shell can treat the second part of the key as a command.

Then start the service:

```bash
brew services start beszel-agent
```

For OrbStack container stats, the default `/var/run/docker.sock` should usually work. If Docker container stats do not appear in Beszel, find OrbStack's Docker endpoint and add it to `~/.config/beszel/beszel-agent.env`:

```bash
docker context inspect orbstack --format '{{ (index .Endpoints "docker").Host }}'
```

```dotenv
DOCKER_HOST="unix:///var/run/docker.sock"
```

Restart after edits:

```bash
brew services restart beszel-agent
```

## Option B: Docker agent

Use this if you want the agent managed entirely by Compose.

If the native macOS agent is already running, stop it first:

```bash
brew services stop beszel-agent
```

```bash
docker compose -f docker-compose.yml -f docker-compose.agent.yml up -d
```

The Docker agent uses `HUB_URL=http://beszel:8090` because it runs on the same Compose network as the hub.

## First boot

Open Beszel at `https://monitoring.${BASE_DOMAIN}` and create an admin account on first visit.

Add a system from the UI, then copy the generated key and token into the agent config.

For the native macOS agent, use the Mac's LAN IP or hostname with port `45876` if using SSH mode. If using `HUB_URL` and token registration, the agent connects outbound to the hub.

When switching from Docker agent to native macOS agent, prefer creating a new system entry or using a universal token. Reusing an existing Docker-agent system can fail with `fingerprint mismatch` because the native agent has a different persistent fingerprint.

If a new native system still reports `fingerprint mismatch`, reset the native agent identity before registering it again:

```bash
brew services stop beszel-agent
mv ~/.config/beszel/fingerprint ~/.config/beszel/fingerprint.bak
```

Then delete the failed system entry in Beszel, create a fresh system or token, update `~/.config/beszel/beszel-agent.env`, and start the agent again:

```dotenv
SYSTEM_NAME="mac-native"
KEY="ssh-ed25519 AAAA..."
TOKEN="<fresh token>"
HUB_URL="https://monitoring.example.com"
LISTEN="45876"
```

```bash
brew services start beszel-agent
```

For the Docker agent, keep the key and token in `.env`, then restart:

```bash
docker compose -f docker-compose.yml -f docker-compose.agent.yml up -d
```

## Notes

- Beszel data is stored in the `beszel_data` volume and survives container restarts.
- Docker agent state is stored in the `beszel_agent_data` volume.
- Native macOS agent config lives in `~/.config/beszel/beszel-agent.env`.
- Native macOS agent logs are written to `~/.cache/beszel/beszel-agent.log`.
- Beszel does not ingest arbitrary custom metrics; use something like Prometheus/Grafana for mactop power telemetry.
