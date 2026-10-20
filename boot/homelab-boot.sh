#!/usr/bin/env bash
# Bring up the stacks in stacks.conf once their prerequisites are ready.
#
# macOS only mounts external drives after a user logs in, and OrbStack
# (also a login item) auto-restarts every `restart: unless-stopped` container
# at the same moment — so containers bind-mounting the drive race it and
# lose. This runs at login, waits for the drive, then (re)creates the gated
# stacks so they pick up the real mount.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
TIMEOUT="${BOOT_TIMEOUT:-900}"

log() { echo "$(date '+%F %T') $*"; }

DISK="$(sed -n 's/^DISK="\(.*\)"$/\1/p' "$ROOT/boot/stacks.conf")"

wait_for() { # description, command...
  local what="$1" waited=0; shift
  until "$@" >/dev/null 2>&1; do
    ((waited >= TIMEOUT)) && { log "timed out waiting for $what"; return 1; }
    sleep 2; waited=$((waited + 2))
  done
  log "ready: $what"
}

# Read the mount table only: touching the volume from a launchd job triggers
# a macOS "removable volumes" privacy prompt that would block this forever.
disk_ready() { mount | grep -qF " on $DISK ("; }

stack_healthy() { # every container in the stack is running and not unhealthy/starting
  local ids id state health
  ids=$(docker compose ps -a -q)
  [[ -n "$ids" ]] || return 1
  for id in $ids; do
    read -r state health < <(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$id")
    case "$state" in
      running) [[ -z "$health" || "$health" == healthy ]] || return 1 ;;
      exited) [[ "$(docker inspect -f '{{.State.ExitCode}}' "$id")" == 0 ]] || return 1 ;; # one-shot helpers
      *) return 1 ;;
    esac
  done
}

wait_for "docker daemon" docker info

while read -r stack gate _; do
  [[ -z "$stack" || "$stack" == \#* || "$stack" == DISK=* ]] && continue
  [[ "$gate" == disk ]] && wait_for "drive $DISK" disk_ready
  log "starting $stack"
  (
    exec </dev/null
    cd "$ROOT/$stack"
    docker compose up -d --force-recreate
    wait_for "$stack healthy" stack_healthy
  ) || log "WARN: $stack did not come up cleanly, continuing"
done < "$ROOT/boot/stacks.conf"

log "done"
