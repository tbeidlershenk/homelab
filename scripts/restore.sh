#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
HOMELAB_USER=$(whoami)
HOMELAB_DIR="$HOME/homelab"
SERVICES_DIR="$HOMELAB_DIR/services"
ENV_FILE="$HOMELAB_DIR/.env"

# Use first script argument as backup drive, or default to /mnt/backup
BACKUP_DRIVE="${1:-/mnt/backup}"
BACKUP_DIR="$BACKUP_DRIVE/volumes"
VOLUMES_DIR=$HOMELAB_DIR/volumes

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Volumes directory not found at $BACKUP_DIR"
    exit 1
fi
echo "Restoring Docker volumes from backup: $BACKUP_DIR"

# Stop all services
bash "$HOMELAB_DIR/scripts/stop-services.sh"

# Confirm before overwriting volumes
read -p "WARNING: This will overwrite existing Docker volumes. Proceed? (confirm YES): " confirm_restore
if [[ "$confirm_restore" != "YES" ]]; then
    echo "Restore aborted."
    exit 0
fi

# Log restore time
echo "Restore time: $TIMESTAMP"
echo "$TIMESTAMP - ran restore" >> "$HOME/homelab/logs/backup.log"

# Restore volumes using rsync
sudo rsync -av "$BACKUP_DIR/" "$VOLUMES_DIR"

# Restart all services
bash "$HOMELAB_DIR/scripts/start-services.sh"

echo "Restore completed successfully!"

