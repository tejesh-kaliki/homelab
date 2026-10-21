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

## Planned: SOCKS5 proxy for native apps (not built yet)

A native Mac app can't join the container's network, but it can use a proxy that runs inside it, so only that app goes through Mullvad.

- Run a SOCKS5 proxy in the `vpn` namespace (Tailscale's `TS_SOCKS5_SERVER`, or a small proxy container with `network_mode: container:vpn`) and publish it on `127.0.0.1:1080` only, so nothing else on the LAN can use the exit.
- Apps that support proxies (browsers, curl, git, ssh `ProxyCommand`) use `socks5h://127.0.0.1:1080`, so DNS goes through the VPN too. Apps that ignore proxies need `proxychains` or a per-app tool like Proxifier.
- **`localhost` and `127.0.0.1` through the proxy mean the container, not the Mac.** Make the app bypass the proxy for local addresses (Firefox "No proxy for", Chrome/Playwright `--proxy-bypass-list`, or a PAC file): `localhost, 127.0.0.1, 192.168.0.0/16, .<BASE_DOMAIN>`.
- LAN and Docker ranges already stay off the VPN (`--exit-node-allow-lan-access`). From inside the namespace, container names on `homelab_proxy` (e.g. `jellyfin:8096`) and the Mac via its gateway IP work.
- To reach the Mac by name, add `extra_hosts: ["host.docker.internal:host-gateway"]` to the `vpn` service (as `tunnel-forwarding` does). Re-creating `vpn` orphans the sonarr stack, so re-create that afterwards.

## Behaviour to know

- **Kill switch:** `entrypoint.sh` rejects any non-root egress that isn't loopback, the tailnet, or a private range, so the apps get no connectivity (rather than a leak) if the exit node drops or the container is starting. IPv6 is blocked for them entirely.
- **Re-creating `vpn`** orphans every container sharing it; re-create those stacks afterwards. `boot/stacks.conf` does this in order at login.
- **No inbound torrent port:** Mullvad no longer offers port forwarding, so qBittorrent can't accept incoming peers (the old `6881` publish is gone). Downloads work; seeding/peer count is lower.
- The auth key is only used on first start; node identity lives in the `tailscale-state` volume.
