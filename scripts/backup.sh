#!/bin/bash
set -euo pipefail

BACKUP_DIR="${BACKUP_PATH:-./backups}/$(date +%Y%m%d_%H%M%S)"
CONFIG_DIR="${CONFIG_PATH:-./config}"

echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

echo "Backing up configurations..."
tar -czf "$BACKUP_DIR/config_backup.tar.gz" "$CONFIG_DIR" 2>/dev/null || true

echo "Backing up databases..."
docker compose exec -T postgres pg_dumpall -U "${POSTGRES_USER:-homelab_user}" \
  > "$BACKUP_DIR/postgres_dump.sql" 2>/dev/null || true

echo "Backing up environment..."
cp .env "$BACKUP_DIR/.env.backup" 2>/dev/null || true
cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml.backup" 2>/dev/null || true

echo "Backup completed: $BACKUP_DIR"
