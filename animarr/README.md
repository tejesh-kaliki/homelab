# animarr

Anime tracker: AniList list in, Nyaa releases to qBittorrent, imports into the Jellyfin library. Source, docs and settings reference: https://github.com/tejesh-kaliki/animarr. This folder only runs the published image.

```sh
cp .env.example .env     # set DATA_DIR and the rest
docker compose up -d     # pulls ghcr.io/tejesh-kaliki/animarr:latest
```

- UI: `https://animarr.${BASE_DOMAIN}` (Caddy), or `http://127.0.0.1:8990` on this Mac. There is no login, so keep it on loopback and the proxy.
- Needs the `vpn` container running first. It shares that network namespace and Caddy reaches it through the `animarr` alias.
- Update: `docker compose pull && docker compose up -d`.
- `config/` holds the SQLite database and `secret.key` (encrypts the settings saved in the UI). Both are in `backup.sh`.
- One-off commands run in the same image, for example `docker compose run --rm --no-deps animarr organize --dry-run`.
- Do not edit `config/animarr.db` with `sqlite3` while the container runs. Stop it first.
