#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
HOMELAB_DIR="$HOME/homelab"
SCRIPTS_DIR="$HOMELAB_DIR/scripts"
VOLUMES_DIR="$HOMELAB_DIR/volumes"
LOGS_DIR="$HOMELAB_DIR/logs"
REGISTRY_FILE="$HOMELAB_DIR/config/registry.json"

# First argument: backup drive, default /mnt/backup
BACKUP_DRIVE="${1:-/mnt/backup}"
BACKUP_DIR="$BACKUP_DRIVE/volumes"

# Second argument: env file name, default .env
ENV_FILE="$HOMELAB_DIR/${2:-.env}"

[ -d "$BACKUP_DRIVE" ] || { echo "ERROR: Backup drive not found at $BACKUP_DRIVE"; exit 1; }

echo "Backing up Docker volumes to: $BACKUP_DIR"

# Pause services marked pause_on_backup: true
echo "Pausing services for backup..."
while IFS= read -r yml_file; do
  project_name=$(basename "$yml_file" .yml)
  echo "Pausing $project_name..."
  docker compose --env-file $ENV_FILE -f "$yml_file" -p "$project_name" pause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$REGISTRY_FILE")

# Log backup time
echo "$TIMESTAMP - ran backup" >> "$LOGS_DIR/backup.log"

# Ensure backup directory exists
sudo mkdir -p "$BACKUP_DIR"

# Run rsync backup
sudo rsync -av "$VOLUMES_DIR/" "$BACKUP_DIR"

# Unpause services after backup
echo "Resuming paused services..."
while IFS= read -r yml_file; do
  project_name=$(basename "$yml_file" .yml)
  echo "Resuming $project_name..."
  docker compose --env-file $ENV_FILE -f "$yml_file" -p "$project_name" unpause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$REGISTRY_FILE")

echo "Backup completed successfully!"
echo "Backed up to directory: $BACKUP_DIR"

