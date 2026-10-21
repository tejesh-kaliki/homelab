#!/usr/bin/env bash
# Back up the critical stacks (Vaultwarden, Firefly III, Memos, plus the
# gitignored .env files that can't be rebuilt from the repo) to the external
# drive. Run by hand or via backup/install.sh (daily launchd job).
#
#   ./backup.sh [dest-dir]     default: $DISK/homelab-backups/<timestamp>
#
# Env: KEEP=14 snapshots to retain, INCLUDE_SONARR=true to add sonarr config.
set -euo pipefail

cd "$(dirname "$0")"
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

DISK="$(sed -n 's/^DISK="\(.*\)"$/\1/p' boot/stacks.conf)"
ROOT_DIR="$DISK/homelab-backups"
KEEP="${KEEP:-14}"
BACKUP_DIR="${1:-$ROOT_DIR/$(date +%Y-%m-%d_%H%M%S)}"

log() { echo "$(date '+%F %T') $*"; }

# Mount table only, same as the boot script: avoids the removable-volume prompt.
if [[ -z "${1:-}" ]] && ! mount | grep -qF " on $DISK ("; then
  log "drive $DISK not mounted, skipping backup"
  exit 0
fi

mkdir -p "$BACKUP_DIR"
STOPPED=()
restart_stopped() { for c in ${STOPPED[@]+"${STOPPED[@]}"}; do docker start "$c" >/dev/null 2>&1 || true; done; }
trap restart_stopped EXIT

# Containers using SQLite get a consistent copy by stopping them for the few
# seconds the tar takes.
tar_stopped() { # container, source-parent-dir, source-name, output
  docker stop "$1" >/dev/null; STOPPED+=("$1")
  tar -czf "$4" -C "$2" "$3"
  docker start "$1" >/dev/null
}

log "==> Backing up to $BACKUP_DIR"

log "[1/4] Vaultwarden"
tar_stopped vaultwarden ./password vw-data "$BACKUP_DIR/vaultwarden.tar.gz"

log "[2/4] Memos"
tar_stopped memos ./memos data "$BACKUP_DIR/memos.tar.gz"

log "[3/4] Firefly III"
# --single-transaction gives a consistent dump without stopping the app.
docker exec firefly_iii_db \
  sh -c 'mariadb-dump --single-transaction -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
  > "$BACKUP_DIR/firefly-db.sql"
docker run --rm \
  -v firefly-iii_firefly_iii_upload:/data:ro \
  -v "$(realpath "$BACKUP_DIR")":/backup \
  alpine tar -czf /backup/firefly-uploads.tar.gz -C /data .

log "[4/4] Env files"
# APP_KEY in firefly's .env is needed to read its data back; the rest are
# credentials. Not in git on purpose, so they live only here.
envs=$(ls ./*/.env ./*/.db.env ./*/.importer.env 2>/dev/null || true)
# shellcheck disable=SC2086
[[ -z "$envs" ]] || tar -czf "$BACKUP_DIR/env-files.tar.gz" $envs
chmod 600 "$BACKUP_DIR"/*

if [[ "${INCLUDE_SONARR:-false}" == "true" ]]; then
  log "[+] Sonarr stack config"
  docker stop sonarr prowlarr qbittorrent >/dev/null 2>&1 || true
  tar -czf "$BACKUP_DIR/sonarr-config.tar.gz" -C ./sonarr config
  docker start sonarr prowlarr qbittorrent >/dev/null 2>&1 || true
fi

# Retention: only prune the timestamped snapshots we create ourselves.
if [[ -z "${1:-}" ]]; then
  ls -1d "$ROOT_DIR"/20??-??-??_?????? 2>/dev/null | sort -r | tail -n +$((KEEP + 1)) | while read -r old; do
    log "pruning $old"; rm -rf "$old"
  done
fi

log "==> Backup complete"
ls -lh "$BACKUP_DIR"
