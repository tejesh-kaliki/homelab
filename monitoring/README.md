# Monitoring — cAdvisor + Prometheus + Grafana

Tracks CPU, RAM, and network usage across all running Docker containers.

## Services

| Service | Port | Purpose |
|---|---|---|
| cAdvisor | 8081 | Scrapes per-container metrics from Docker |
| Prometheus | 9090 | Stores metrics (30 day retention) |
| Grafana | 3000 | Dashboards |

## Start

```bash
docker compose up -d
```

## First boot

Open Grafana at http://localhost:3000 — login `admin` / `admin`, it will prompt you to change the password.

Prometheus is pre-wired as the default datasource via provisioning — nothing to configure.

### Load the cAdvisor dashboard

Grafana has a community dashboard that works out of the box:

1. Dashboards → Import
2. Enter ID `19792` (cAdvisor + Prometheus, well maintained)
3. Select Prometheus as the datasource → Import

You'll immediately see per-container CPU, RAM, and network graphs for every running container across all your stacks.

## Notes

- Prometheus data is stored in a named Docker volume (`prometheus_data`) — survives container restarts
- Grafana state (dashboards you save, users) is in `grafana_data` volume
- `config/prometheus.yml` and `config/grafana/provisioning/` are the only files we own — everything else is runtime
