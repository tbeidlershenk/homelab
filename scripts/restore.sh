#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/homelab"
SERVICES_DIR="$BASE_DIR/services"
ENV_FILE="$BASE_DIR/.env"
BACKUP_DIR="${1:-/mnt/backup}"  # Default backup location if none provided

# If multiple backups exist, pick the latest
LATEST_BACKUP=$(ls -td "$BACKUP_DIR"/docker_volumes_backup_* 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "ERROR: No backup found in $BACKUP_DIR"
    exit 1
fi

echo "Restoring Docker volumes from backup: $LATEST_BACKUP"

# Stop all services
bash "$BASE_DIR/scripts/stop-services.sh"

# Confirm before overwriting volumes
read -p "WARNING: This will overwrite existing Docker volumes. Proceed? (confirm YES): " confirm_restore
if [[ "$confirm_restore" != "YES" ]]; then
    echo "Restore aborted."
    exit 0
fi

# Restore volumes using rsync
sudo rsync -av "$LATEST_BACKUP/" /var/lib/docker/volumes/

# Fix permissions if needed
sudo chown -R root:root /var/lib/docker/volumes/

# Restart all services
bash "$BASE_DIR/scripts/start-services.sh"

echo "Restore completed successfully!"

