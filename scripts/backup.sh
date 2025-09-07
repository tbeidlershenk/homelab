#!/usr/bin/env bash
set -e

# Use first script argument as backup drive, or default to /mnt/backup
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
BACKUP_DRIVE="${1:-/mnt/backup}"
BACKUP_DIR="$BACKUP_DRIVE/volumes"
VOLUMES_DIR="$HOME/homelab/volumes"

HOMELAB_USER=$(whoami)

if [ ! -d "$BACKUP_DRIVE" ]; then
  echo "ERROR: Backup drive not found at $BACKUP_DRIVE"
  exit 1
fi
echo "Backing up Docker volumes to: $BACKUP_DIR"

# Stop all services
echo "Stopping stacks for backup..."
bash "$HOME/homelab/scripts/stop-services.sh"

# Log backup time
echo "Backup time: $TIMESTAMP"
echo "$TIMESTAMP - ran backup" >> "$HOME/homelab/logs/backup.log"

# Create backup directory if it doesn't exist
echo "Backing up Docker volumes to $BACKUP_DIR..."
sudo mkdir -p "$BACKUP_DIR"

# Backup all Docker volumes
sudo rsync -av "$VOLUMES_DIR/" "$BACKUP_DIR"

# Restart all services
echo "Restarting stacks..."
bash "$HOME/homelab/scripts/start-services.sh"

echo "Backup completed successfully!"
echo "Backup directory: $BACKUP_DIR"

