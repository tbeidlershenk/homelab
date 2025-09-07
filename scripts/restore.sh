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

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory not found at $BACKUP_DIR"
    exit 1
fi
echo "Restoring Docker volumes from backup: $BACKUP_DIR"

# Stop all services
echo "Stopping all services..."
bash "$SCRIPTS_DIR/stop-services.sh"

# Confirm before overwriting volumes
read -p "WARNING: This will overwrite existing Docker volumes at $VOLUMES_DIR. Proceed? (confirm YES): " confirm_restore
if [[ "$confirm_restore" != "YES" ]]; then
    echo "Restore aborted."
    exit 0
fi

# Log restore time
echo "Restore time: $TIMESTAMP"
echo "$TIMESTAMP - ran restore" >> "$LOGS_DIR/backup.log"

# Restore volumes
sudo rsync -av "$BACKUP_DIR/" "$VOLUMES_DIR"

# Restart all services
echo "Restarting all services..."
bash "$SCRIPTS_DIR/start-services.sh"

echo "Restore completed successfully!"
echo "Restored from backup directory: $BACKUP_DIR"

