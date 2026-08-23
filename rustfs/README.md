# RustFS

S3-compatible object storage, served behind the shared Caddy proxy.

## URLs

- Console: `https://rustfs.${BASE_DOMAIN}`
- S3 API: `https://rustfs-s3.${BASE_DOMAIN}`

Ports are declared with `expose` only, so they're reachable from other
containers on the `homelab_proxy` network but not published to the host.
For direct host access (e.g. `http://localhost:9001`), add a `ports:` block
to `docker-compose.yml`:

```yaml
ports:
  - "9000:9000" # S3 API
  - "9001:9001" # Console
```

## Setup

Copy `.env.example` to `.env` and fill in `RUSTFS_PATH`, `RUSTFS_ACCESS_KEY`,
and `RUSTFS_SECRET_KEY`.

## Start

```bash
docker compose up -d
```

The `volume-permission-helper` service runs once on startup to fix
ownership on `RUSTFS_PATH`, then exits — this is expected.
