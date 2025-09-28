#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
HOMELAB_USER=$(whoami)
HOMELAB_DIR="$HOME/homelab"
SCRIPTS_DIR="$HOMELAB_DIR/scripts"
VOLUMES_DIR="$HOMELAB_DIR/volumes"
LOGS_DIR="$HOMELAB_DIR/logs"
REGISTRY_FILE="$HOMELAB_DIR/config/registry.json"

# First argument: backup drive, default /mnt/backup
BACKUP_DRIVE="${1:-/mnt/backup}"
BACKUP_DIR="$BACKUP_DRIVE/volumes"

# Second argument: env file name, default .env
ENV_FILE="${1:-$HOMELAB_DIR/.env}"

[ -d "$BACKUP_DIR" ] || { echo "ERROR: Backup directory not found at $BACKUP_DIR"; exit 1; }

echo "Restoring Docker volumes from backup: $BACKUP_DIR"

# Pause services marked pause_on_backup: true
echo "Pausing services for restore..."
while IFS= read -r yml_file; do
  project_name=$(basename "$yml_file" .yml)
  echo "Pausing $project_name..."
  docker compose --env-file $ENV_FILE -f "$yml_file" -p "$project_name" pause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$REGISTRY_FILE")

# Confirm before overwriting volumes
read -p "WARNING: This will overwrite existing Docker volumes at $VOLUMES_DIR. Proceed? (confirm YES): " confirm_restore
if [[ "$confirm_restore" != "YES" ]]; then
    echo "Restore aborted."
    exit 0
fi

# Log restore time
echo "$TIMESTAMP - ran restore" >> "$LOGS_DIR/backup.log"

# Restore volumes
sudo rsync -av "$BACKUP_DIR/" "$VOLUMES_DIR"

# Resume paused services
echo "Resuming paused services..."
while IFS= read -r yml_file; do
  project_name=$(basename "$yml_file" .yml)
  echo "Resuming $project_name..."
  docker compose --env-file $ENV_FILE -f "$yml_file" -p "$project_name" unpause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$REGISTRY_FILE")

echo "Restore completed successfully!"
echo "Restored from backup directory: $BACKUP_DIR"

