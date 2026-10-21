#!/bin/sh
# Kill switch for everything sharing this network namespace.
#
# Tailscale routes all traffic through the exit node, but while it is starting,
# restarting, or has lost the exit node the default route is the plain Docker
# gateway. Processes running as a non-root user (the linuxserver apps drop to
# uid 1000) may only send over loopback, the tailnet, or to private ranges;
# anything else is rejected. tailscaled itself runs as root and is unaffected.
set -eu

PRIVATE="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16"

iptables -F OUTPUT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o tailscale0 -j ACCEPT
for net in $PRIVATE; do
  iptables -A OUTPUT -d "$net" -j ACCEPT
done
iptables -A OUTPUT -m owner ! --uid-owner 0 -j REJECT

# No IPv6 for the apps at all
ip6tables -F OUTPUT
ip6tables -A OUTPUT -o lo -j ACCEPT
ip6tables -A OUTPUT -o tailscale0 -j ACCEPT
ip6tables -A OUTPUT -m owner ! --uid-owner 0 -j REJECT

# `tailscale up` refuses an exit node given by hostname, so start the node
# first and select the exit node once it has its netmap.
/usr/local/bin/containerboot &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null' TERM INT
(
  until tailscale set --exit-node="$MULLVAD_EXIT_NODE" --exit-node-allow-lan-access >/dev/null 2>&1; do
    sleep 2
  done
  echo "vpn: exit node set to $MULLVAD_EXIT_NODE"
) &
wait "$pid"
