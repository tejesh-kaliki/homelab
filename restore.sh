#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:?Usage: ./restore.sh <backup-dir>}"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Error: $BACKUP_DIR not found"
  exit 1
fi

echo "==> Restoring from $BACKUP_DIR"

# --- Vaultwarden ---
if [[ -f "$BACKUP_DIR/vaultwarden.tar.gz" ]]; then
  echo "[1/3] Vaultwarden"
  docker stop vaultwarden 2>/dev/null || true
  rm -rf ./password/vw-data
  mkdir -p ./password/vw-data
  tar -xzf "$BACKUP_DIR/vaultwarden.tar.gz" -C ./password
  docker start vaultwarden 2>/dev/null || true
  echo "     done"
fi

# --- Firefly III ---
if [[ -f "$BACKUP_DIR/firefly-db.sql" ]]; then
  echo "[2/3] Firefly III"
  docker stop firefly_iii_core 2>/dev/null || true

  # Restore database
  docker exec -i firefly_iii_db \
    sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
    < "$BACKUP_DIR/firefly-db.sql"

  # Restore uploads
  if [[ -f "$BACKUP_DIR/firefly-uploads.tar.gz" ]]; then
    docker run --rm \
      -v firefly-iii_firefly_iii_upload:/data \
      -v "$(realpath "$BACKUP_DIR")":/backup \
      alpine tar -xzf /backup/firefly-uploads.tar.gz -C /data
  fi

  docker start firefly_iii_core 2>/dev/null || true
  echo "     done"
fi

# --- Sonarr stack (optional) ---
if [[ -f "$BACKUP_DIR/sonarr-config.tar.gz" ]]; then
  echo "[3/3] Sonarr stack config"
  docker stop sonarr prowlarr qbittorrent 2>/dev/null || true
  rm -rf ./sonarr/config
  mkdir -p ./sonarr/config
  tar -xzf "$BACKUP_DIR/sonarr-config.tar.gz" -C ./sonarr
  docker start sonarr prowlarr qbittorrent 2>/dev/null || true
  echo "     done"
fi

echo ""
echo "==> Restore complete"
