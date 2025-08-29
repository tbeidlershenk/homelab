#!/usr/bin/env bash
set -e

# Use first script argument as backup drive, or default to /mnt/backup
BACKUP_DRIVE="${1:-/mnt/backup}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_DRIVE/docker_volumes_backup_$TIMESTAMP"

if [ ! -d "$BACKUP_DRIVE" ]; then
  echo "ERROR: Backup drive not found at $BACKUP_DRIVE"
  exit 1
fi

echo "Stopping stacks for backup..."
bash "$HOME/homelab/scripts/stop-services.sh"

echo "Backing up Docker volumes to $BACKUP_DIR..."
sudo mkdir -p "$BACKUP_DIR"

# rsync all Docker volumes
sudo rsync -av /var/lib/docker/volumes/ "$BACKUP_DIR/"

echo "Restarting stacks..."
bash "$HOME/homelab/scripts/start-services.sh"

echo "Backup completed successfully!"
echo "Backup directory: $BACKUP_DIR"

