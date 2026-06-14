#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-./backups/$(date +%Y-%m-%d)}"
mkdir -p "$BACKUP_DIR"

echo "==> Backing up to $BACKUP_DIR"

# --- Vaultwarden ---
echo "[1/3] Vaultwarden"
docker stop vaultwarden 2>/dev/null || true
tar -czf "$BACKUP_DIR/vaultwarden.tar.gz" -C ./password vw-data
docker start vaultwarden 2>/dev/null || true
echo "     done: vaultwarden.tar.gz"

# --- Firefly III ---
echo "[2/3] Firefly III"
docker stop firefly_iii_core 2>/dev/null || true

# Database dump
docker exec firefly_iii_db \
  sh -c 'mariadb-dump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
  > "$BACKUP_DIR/firefly-db.sql"

# Uploads volume
docker run --rm \
  -v firefly-iii_firefly_iii_upload:/data \
  -v "$(realpath "$BACKUP_DIR")":/backup \
  alpine tar -czf /backup/firefly-uploads.tar.gz -C /data .

docker start firefly_iii_core 2>/dev/null || true
echo "     done: firefly-db.sql, firefly-uploads.tar.gz"

# --- Sonarr stack (optional) ---
if [[ "${INCLUDE_SONARR:-false}" == "true" ]]; then
  echo "[3/3] Sonarr stack config"
  docker stop sonarr prowlarr qbittorrent 2>/dev/null || true
  tar -czf "$BACKUP_DIR/sonarr-config.tar.gz" -C ./sonarr config
  docker start sonarr prowlarr qbittorrent 2>/dev/null || true
  echo "     done: sonarr-config.tar.gz"
else
  echo "[3/3] Sonarr skipped (set INCLUDE_SONARR=true to include)"
fi

echo ""
echo "==> Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
