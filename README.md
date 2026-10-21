# Homelab

Docker Compose stacks for a Mac mini homelab (OrbStack). Each top-level directory is one stack with its own `docker-compose.yml`. Secrets live in gitignored `.env` files; copy each `.env.example` and fill it in.

## Stacks

| Stack | What it is |
|---|---|
| `proxy` | Caddy reverse proxy with Cloudflare DNS-01 TLS. Serves `<service>.${BASE_DOMAIN}` and owns the shared `homelab_proxy` network |
| `password` | Vaultwarden |
| `firefly-iii` | Firefly III finance manager (app, MariaDB, cron) |
| `memos` | Memos notes (SQLite) |
| `rustfs` | S3-compatible object storage on the external drive |
| `bifrost` | Bifrost LLM gateway, uses RustFS |
| `vpn` | Tailscale node using a Mullvad exit node; other containers share its network (see `vpn/README.md`) |
| `sonarr` | Sonarr, Prowlarr, qBittorrent, Jellyfin media stack (all but Jellyfin egress via `vpn`) |
| `speaches` | Speech-to-text / TTS server |
| `monitoring` | Beszel hub and agent |
| `tunnel-forwarding` | Tunnel forwarding service |

Stacks that serve a web UI join the external `homelab_proxy` network, which has to exist before they start:

```sh
docker network create homelab_proxy
```

To add a service, add a host block to `proxy/Caddyfile` and put the container on that network. Some stacks have their own README with more detail (`monitoring`, `rustfs`, `sonarr`, `speaches`, `vpn`).

## Boot ordering

macOS only mounts external drives after login, and OrbStack restarts containers at the same moment, so containers that bind-mount the drive can race it and lose. `boot/` handles this:

- `boot/stacks.conf` lists the stacks that must wait for the drive (`DISK`) or for an earlier stack to be healthy, in start order.
- `boot/homelab-boot.sh` waits for Docker and the drive, then recreates those stacks.
- `boot/install.sh` installs it as a launchd agent that runs at login. Log: `~/Library/Logs/homelab-boot.log`.

## Backups

`backup.sh` writes timestamped snapshots to `$DISK/homelab-backups/` (the drive from `boot/stacks.conf`). It does nothing if the drive isn't mounted, and keeps the newest 14 snapshots (`KEEP=n` to change).

| Backed up | How |
|---|---|
| Vaultwarden | `password/vw-data` tarball, container stopped for a few seconds |
| Memos | `memos/data` tarball, container stopped for a few seconds |
| Firefly III | `mariadb-dump --single-transaction` plus the uploads volume, app stays up |
| `.env` files | Tarball of every stack's gitignored env files (Firefly's `APP_KEY` is needed to read its data) |
| Sonarr config | Only with `INCLUDE_SONARR=true` |

```sh
./backup.sh                      # snapshot to the drive
./backup.sh /some/dir            # snapshot to a specific dir (no pruning)
./backup/install.sh              # run it daily at 03:30 via launchd
./restore.sh <snapshot-dir>      # restore; RESTORE_ENV=true also restores .env files
```

Backup log: `~/Library/Logs/homelab-backup.log`.

Things to know:

- The snapshots sit on a drive in the same room as the Mac. There is no offsite copy yet.
- The `.env` tarball is not encrypted. Don't let the drive leave your control, or encrypt that archive first.
- Restore overwrites the current data for each stack it finds in the snapshot.
- Bifrost, monitoring, RustFS contents and media are not backed up.
