#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
HOMELAB_USER=$(whoami)
HOMELAB_DIR="$HOME/homelab"
SERVICES_DIR="$HOMELAB_DIR/services"
SCRIPTS_DIR="$HOMELAB_DIR/scripts"
VOLUMES_DIR=$HOMELAB_DIR/volumes
LOGS_DIR="$HOMELAB_DIR/logs"
ENV_FILE="$HOMELAB_DIR/.env"

# Use first script argument as backup drive
# Default to /mnt/backup
BACKUP_DRIVE="${1:-/mnt/backup}"
BACKUP_DIR="$BACKUP_DRIVE/volumes"

if [ ! -d "$BACKUP_DRIVE" ]; then
    echo "ERROR: Backup drive not found at $BACKUP_DRIVE"
    exit 1
fi
echo "Backing up Docker volumes to: $BACKUP_DIR"

# Stop all services
echo "Stopping all services..."
bash "$SCRIPTS_DIR/stop-services.sh"

# Log backup time
echo "Backup time: $TIMESTAMP"
echo "$TIMESTAMP - ran backup" >> "$LOGS_DIR/backup.log"

# Create backup directory if it doesn't exist
echo "Backing up Docker volumes to $BACKUP_DIR..."
sudo mkdir -p "$BACKUP_DIR"

# Backup volumes
sudo rsync -av "$VOLUMES_DIR/" "$BACKUP_DIR"

# Restart all services
echo "Restarting all services..."
bash "$SCRIPTS_DIR/start-services.sh"

echo "Backup completed successfully!"
echo "Backed up to directory: $BACKUP_DIR"

