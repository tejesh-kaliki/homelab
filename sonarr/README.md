# Media stack — qBittorrent + animarr + Jellyfin

animarr follows an AniList list, sends Nyaa releases to qBittorrent and imports them into the Jellyfin library. Source, docs and settings reference: https://github.com/tejesh-kaliki/animarr. This stack only runs the published image.

## Services

| Service | Port | Purpose |
|---|---|---|
| animarr | 8990 | Anime tracker (AniList → Nyaa → qBittorrent → Jellyfin). No login, so keep it on loopback and the proxy |
| qBittorrent | 8080 | Torrent download client |
| Jellyfin | 8096 | Media server for streaming |

## VPN

animarr and qBittorrent run inside the `vpn` stack's network namespace (`network_mode: container:vpn`), so their internet traffic exits through Mullvad. Jellyfin does not. Start `vpn` first, and re-create this stack (`docker compose up -d --force-recreate`) whenever the `vpn` container is re-created. Caddy reaches them through the aliases on the `vpn` service; see `vpn/README.md`.

## Layout and config

```
sonarr/
├── docker-compose.yml
├── .env                # DATA_DIR and animarr settings, not committed (see below)
├── config/             # Runtime-generated, not committed: animarr/ qbittorrent/ jellyfin/
└── data/               # Downloads and media, not committed (downloads/, media/anime/)
```

`.env` keys: `DATA_DIR` (host dir mounted at `/data`, e.g. an external drive), `ANILIST_USERNAME`, `ANILIST_TOKEN`, `AUTOMATION_ENABLED`, `QB_USERNAME`, `QB_PASSWORD`, `JELLYFIN_URL`, `JELLYFIN_API_KEY`, optional `ANIMARR_SECRET_KEY`.

```bash
docker compose up -d
```

## Notes

- UI: `https://animarr.${BASE_DOMAIN}` (Caddy), or `http://127.0.0.1:8990` on this Mac.
- Update animarr: `docker compose pull animarr && docker compose up -d`.
- `config/animarr/` holds the SQLite database and `secret.key`; both are in `backup.sh`. Stop the container before touching the DB.
- One-off commands: `docker compose run --rm --no-deps animarr organize --dry-run`.

## qBittorrent first boot

Open http://localhost:8080. The generated password is in `docker logs qbittorrent | grep -i password`. Set **Downloads → Default Save Path** to `/data/downloads`, and seeding to remove the torrent and its files after `10080` min (7 days). Jellyfin library: **Shows** → `/media/anime`.
