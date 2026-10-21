# VPN — Tailscale + Mullvad

A Tailscale node that routes everything through a Mullvad exit node. Containers opt in with `network_mode: container:vpn`; they then share this container's network, so their internet traffic leaves through Mullvad. Private ranges (LAN, Docker networks, other stacks) go direct, so e.g. Jellyfin and Caddy are unaffected.

Currently used by Sonarr, Prowlarr and qBittorrent (`sonarr/`).

## Setup

1. In the Tailscale admin console, enable the **Mullvad exit nodes** add-on and assign it to this device. If the auth key is tagged (e.g. `tag:homeserver`), the device is owned by the tag, so the ACL also needs `{"target": ["tag:homeserver"], "attr": ["mullvad"]}` under `nodeAttrs`; without it `tailscale exit-node list` shows no exit nodes.
2. Create an auth key (Settings → Keys).
3. `cp .env.example .env`, fill in `TS_AUTHKEY` and `MULLVAD_EXIT_NODE` (a name from `docker exec vpn tailscale exit-node list`, e.g. `se-sto-wg-001.mullvad.ts.net`).
4. `docker compose up -d`, then `docker compose ps` — it is `healthy` once traffic really exits via Mullvad.
5. Re-create the sonarr stack: `cd ../sonarr && docker compose up -d --force-recreate`.

Check: `docker exec sonarr wget -qO- https://am.i.mullvad.net/connected`.

## Adding another container

```yaml
my-browser:
  network_mode: container:vpn
```

If it serves a web UI through Caddy, add its container name as an extra alias under `networks.homelab_proxy.aliases` in `docker-compose.yml` and point Caddy at `<alias>:<port>`. Ports must not clash with the other containers in the namespace (8989, 9696, 8080).

## Behaviour to know

- **Kill switch:** `entrypoint.sh` rejects any non-root egress that isn't loopback, the tailnet, or a private range, so the apps get no connectivity (rather than a leak) if the exit node drops or the container is starting. IPv6 is blocked for them entirely.
- **Re-creating `vpn`** orphans every container sharing it; re-create those stacks afterwards. `boot/stacks.conf` does this in order at login.
- **No inbound torrent port:** Mullvad no longer offers port forwarding, so qBittorrent can't accept incoming peers (the old `6881` publish is gone). Downloads work; seeding/peer count is lower.
- The auth key is only used on first start; node identity lives in the `tailscale-state` volume.
